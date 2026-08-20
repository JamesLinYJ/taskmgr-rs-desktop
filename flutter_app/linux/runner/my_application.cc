// +-------------------------------------------------------------------------
//
//   taskmgr-rs - Linux Flutter 窗口启动与桌面装饰适配
//
//   文件:       flutter_app/linux/runner/my_application.cc
//
//   日期:       2026年08月21日
//   环境:       Fedora Linux 46 x86_64；Flutter 3.44.7；GTK 3；KDE Wayland
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   GTK 3 GtkApplication/GtkHeaderBar；XDG_CURRENT_DESKTOP；Wayland/X11
// --------------------------------------------------------------------------

#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

namespace {
constexpr char kDefaultWindowTitle[] = "Windows NT Task Manager";
constexpr int kOriginalWindowWidth = 396;
constexpr int kOriginalWindowHeight = 401;

gboolean desktop_prefers_server_decorations() {
  const gchar* desktop = g_getenv("XDG_CURRENT_DESKTOP");
  if (desktop == nullptr) {
    return FALSE;
  }
  g_autofree gchar* lowercase = g_ascii_strdown(desktop, -1);
  return g_strrstr(lowercase, "kde") != nullptr ||
         g_strrstr(lowercase, "plasma") != nullptr;
}

void configure_compact_header_bar(GtkHeaderBar* header_bar) {
  constexpr char kHeaderBarCss[] =
      ".taskmgr-compact-header {"
      "  min-height: 30px;"
      "  padding: 0 6px;"
      "  border-radius: 8px 8px 0 0;"
      "}"
      ".taskmgr-compact-header button.titlebutton {"
      "  min-width: 24px;"
      "  min-height: 24px;"
      "  margin: 2px;"
      "  padding: 0;"
      "  border-radius: 6px;"
      "}";
  GtkWidget* widget = GTK_WIDGET(header_bar);
  gtk_style_context_add_class(gtk_widget_get_style_context(widget),
                              "taskmgr-compact-header");
  gtk_header_bar_set_has_subtitle(header_bar, FALSE);

  GtkCssProvider* provider = gtk_css_provider_new();
  g_autoptr(GError) error = nullptr;
  if (!gtk_css_provider_load_from_data(provider, kHeaderBarCss, -1, &error)) {
    g_warning("Failed to apply compact title bar style: %s", error->message);
  } else {
    gtk_style_context_add_provider_for_screen(
        gtk_widget_get_screen(widget), GTK_STYLE_PROVIDER(provider),
        GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
  }
  g_object_unref(provider);
}
}  // namespace

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
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
  gboolean use_header_bar = !desktop_prefers_server_decorations();
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
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    configure_compact_header_bar(header_bar);
    GBinding* title_binding =
        g_object_bind_property(window, "title", header_bar, "title",
                               G_BINDING_SYNC_CREATE);
    g_object_set_data_full(G_OBJECT(window), "taskmgr-title-binding",
                           title_binding, g_object_unref);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  }
  gtk_window_set_title(window, kDefaultWindowTitle);

  gtk_window_set_default_size(window, kOriginalWindowWidth,
                              kOriginalWindowHeight);

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
