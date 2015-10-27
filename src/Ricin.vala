public class Ricin.Ricin : Gtk.Application {
  const ActionEntry[] actions = {
    { "settings", show_settings },
    { "about", show_about },
    { "quit", quit }
  };

  void show_settings () {

  }

  void show_about () {

  }

  public Ricin () {
    Object (application_id: "chat.tox.ricin",
            flags: ApplicationFlags.FLAGS_NONE); // TODO: handle open
  }

  public override void activate () {
    add_action_entries (actions, this);

    var provider = new Gtk.CssProvider ();
    provider.load_from_resource(@"$resource_base_path/style.css");
    Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (),
        provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

    Notify.init ("Ricin");

    new ProfileChooser (this);
  }

  public static int main(string[] args) {
    return new Ricin ().run (args);
  }
}
