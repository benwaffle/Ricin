using Tox;

[GtkTemplate (ui="/chat/tox/ricin/ui/friend-list-row.ui")]
class Ricin.FriendListRow : Gtk.ListBoxRow {
  [GtkChild] public Gtk.Image avatar;
  [GtkChild] public Gtk.Label username;
  [GtkChild] Gtk.Label status;
  [GtkChild] Gtk.Image userstatus;

  public Tox.Friend fr;
  private MenuItem toggle_friend_item;
  private weak MainWindow main_window;

  const ActionEntry[] actions = {
    { "toggle-block", toggle_block_friend },
    { "remove", remove_friend }
  };

  void toggle_block_friend () {
    fr.blocked = !fr.blocked;
  }

  void remove_friend () {
    main_window.remove_friend (fr);
  }

  public FriendListRow (Tox.Friend fr, MainWindow main_window) {
    this.fr = fr;
    this.main_window = main_window;
    if (fr.name == null) {
      this.username.set_text (this.fr.pubkey);
      this.status.set_text ("");
    }

    var group = new SimpleActionGroup ();
    group.add_action_entries (actions, this);
    this.insert_action_group ("friend", group);

    var menu_model = new Menu ();
    toggle_friend_item = new MenuItem ("Block", "friend.toggle-block");
    menu_model.append_item (toggle_friend_item);
    menu_model.append ("Remove", "friend.remove");

    fr.notify["blocked"].connect ((obj, prop) => {
      toggle_friend_item.set_label (fr.blocked ? "Unblock" : "Block");
    });

    var menu = new Gtk.Menu.from_model (menu_model);
    menu.attach_widget = this;
    this.button_press_event.connect (event => {
      if (event.button == Gdk.BUTTON_SECONDARY) {
        menu.popup (null, null, null, event.button, event.time);
        return Gdk.EVENT_STOP;
      } else {
        return Gdk.EVENT_PROPAGATE;
      }
    });

    // Load the avatar from the avatar cache located in ~/.config/tox/avatars/
    var avatar_path = Tox.profile_dir () + "avatars/" + this.fr.pubkey + ".png";
    if (FileUtils.test (avatar_path, FileTest.EXISTS)) {
      var pixbuf = new Gdk.Pixbuf.from_file_at_scale (avatar_path, 48, 48, false);
      this.avatar.pixbuf = pixbuf;
    }

    fr.bind_property ("name", username, "label", BindingFlags.DEFAULT);
    fr.bind_property ("status-message", status, "label", BindingFlags.DEFAULT);
    fr.avatar.connect (p => avatar.pixbuf = p);

    fr.notify["status"].connect ((obj, prop) => {
      string icon = "";

      switch (fr.status) {
        case UserStatus.BLOCKED:
          icon = "action-unavailable-symbolic";
          break;
        case UserStatus.ONLINE:
          icon = "user-available";
          break;
        case UserStatus.AWAY:
          icon = "user-away";
          break;
        case UserStatus.BUSY:
          icon = "user-busy";
          break;
        case UserStatus.OFFLINE:
        default:
          icon = "user-offline";
          break;
      }
      this.userstatus.set_from_icon_name (icon, Gtk.IconSize.BUTTON);
      this.changed (); // we sort by user status
    });
  }
}
