#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif
#ifdef STANDUP_HAVE_XSCRNSAVER
#include <X11/Xlib.h>
#include <X11/extensions/scrnsaver.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Reads the X11 idle counter, in milliseconds, or -1 when the session cannot
// answer.
//
// MIT-SCREEN-SAVER is an X11 extension. A Wayland session has no equivalent, and
// GTK may be talking to XWayland, where the extension is normally absent and the
// query fails; that is reported honestly as "unknown" rather than as an active
// user. A build without the XScreenSaver development headers compiles this out
// to the same answer, so a missing optional package can never break the build.
static gint64 x11_idle_milliseconds() {
#if defined(GDK_WINDOWING_X11) && defined(STANDUP_HAVE_XSCRNSAVER)
  GdkDisplay* display = gdk_display_get_default();
  if (display == nullptr || !GDK_IS_X11_DISPLAY(display)) {
    return -1;
  }

  Display* x_display = gdk_x11_display_get_xdisplay(display);
  if (x_display == nullptr) {
    return -1;
  }

  int event_base = 0;
  int error_base = 0;
  if (!XScreenSaverQueryExtension(x_display, &event_base, &error_base)) {
    return -1;
  }

  XScreenSaverInfo* info = XScreenSaverAllocInfo();
  if (info == nullptr) {
    return -1;
  }

  gint64 idle_milliseconds = -1;
  if (XScreenSaverQueryInfo(x_display, DefaultRootWindow(x_display), info)) {
    idle_milliseconds = static_cast<gint64>(info->idle);
  }
  XFree(info);
  return idle_milliseconds;
#else
  return -1;
#endif
}

// Answers `standup/presence` with how long the session has been untouched.
//
// The reading never leaves the machine: it only decides whether a reminder is
// allowed to sound. A null result means "unknown", and the Dart side holds its
// previous state for it — a fabricated zero would claim an active user.
static void presence_method_call_cb(FlMethodChannel* channel,
                                    FlMethodCall* method_call,
                                    gpointer user_data) {
  g_autoptr(FlMethodResponse) response = nullptr;

  if (g_strcmp0(fl_method_call_get_name(method_call), "getIdleTime") == 0) {
    const gint64 idle_milliseconds = x11_idle_milliseconds();
    if (idle_milliseconds < 0) {
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    } else {
      g_autoptr(FlValue) idle = fl_value_new_int(idle_milliseconds);
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(idle));
    }
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("Failed to send presence response: %s", error->message);
  }
}

// Answers `standup/window` so the forced break can keep the window above other
// applications.
//
// `gtk_window_set_keep_above` maps to `_NET_WM_STATE_ABOVE` under X11, which
// window managers honour. Wayland has no equivalent protocol, so compositors are
// free to ignore the request; the method still succeeds (the caller must never
// be told a hint failed) and the platform note in docs/PLATFORM_SETUP.md says
// the cover may not survive there.
static void window_method_call_cb(FlMethodChannel* channel,
                                 FlMethodCall* method_call,
                                 gpointer user_data) {
  GtkWindow* window = GTK_WINDOW(user_data);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (g_strcmp0(fl_method_call_get_name(method_call), "setKeepAbove") == 0) {
    // Only an explicit true raises the window; a malformed argument can only
    // lower it, never wedge it on top.
    gboolean keep_above = FALSE;
    FlValue* arguments = fl_method_call_get_args(method_call);
    if (arguments != nullptr &&
        fl_value_get_type(arguments) == FL_VALUE_TYPE_MAP) {
      FlValue* value = fl_value_lookup_string(arguments, "value");
      if (value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_BOOL) {
        keep_above = fl_value_get_bool(value);
      }
    }
    gtk_window_set_keep_above(window, keep_above);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("Failed to send window response: %s", error->message);
  }
}

// Attaches a method channel to @window.
//
// The reference lives on the window itself, so each handler is alive exactly as
// long as the widget it acts on and nothing has to be unwound at shutdown.
static void attach_channel(GtkWindow* window, const gchar* name,
                           FlBinaryMessenger* messenger, FlMethodCodec* codec,
                           FlMethodChannelMethodCallHandler handler) {
  FlMethodChannel* channel = fl_method_channel_new(messenger, name, codec);
  fl_method_channel_set_method_call_handler(channel, handler, window, nullptr);
  g_object_set_data_full(G_OBJECT(window), name, channel, g_object_unref);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "CNPS StandUp");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "CNPS StandUp");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  // Both channels are attached to the window, so neither handler can outlive
  // the widget it acts on.
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlBinaryMessenger* messenger =
      fl_engine_get_binary_messenger(fl_view_get_engine(view));
  attach_channel(window, "standup/presence", messenger, FL_METHOD_CODEC(codec),
                 presence_method_call_cb);
  attach_channel(window, "standup/window", messenger, FL_METHOD_CODEC(codec),
                 window_method_call_cb);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
