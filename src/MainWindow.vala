[GtkTemplate (ui="/chat/tox/ricin/ui/main-window.ui")]
public class Ricin.MainWindow : Gtk.ApplicationWindow {
  [GtkChild] Gtk.Paned paned_header;
  [GtkChild] Gtk.Paned paned_main;
  [GtkChild] Gtk.HeaderBar headerbar_right;
  [GtkChild] Gtk.Button button_call;
  [GtkChild] Gtk.Button button_video_chat;

  [GtkChild] Gtk.Image avatar_image;
  [GtkChild] Gtk.Entry entry_name;
  [GtkChild] Gtk.Entry entry_status;
  [GtkChild] Gtk.Button button_user_status;
  [GtkChild] Gtk.Image image_user_status;

  [GtkChild] Gtk.ListBox friendlist;
  [GtkChild] public Gtk.Stack chat_stack;
  [GtkChild] public Gtk.Button button_add_friend_show;

  // Add friend revealer.
  [GtkChild] public Gtk.Revealer add_friend;
  [GtkChild] public Gtk.Entry entry_friend_id;
  [GtkChild] Gtk.TextView entry_friend_message;
  [GtkChild] Gtk.Label label_add_error;

  // System notify.
  [GtkChild] public Gtk.Revealer revealer_system_notify;
  [GtkChild] public Gtk.Label label_system_notify;

  private ListStore friends = new ListStore (typeof (Tox.Friend));

  public Tox.Tox tox;
  public string focused_view;

  public signal void notify_message (string message, int timeout = 5000);

  private string avatar_path () {
    return Tox.profile_dir () + "avatars/" + this.tox.pubkey + ".png";
  }

  /**
  * This is the sort method used for sorting contacts based on:
  * Contact is online (top) → Contact is offline (end)
  * Contact status: Online → Away → Busy → Offline.
  */
  public static int sort_friendlist_online (Gtk.Widget row1, Gtk.Widget row2) {
    var friend1 = (row1 as FriendListRow);
    var friend2 = (row2 as FriendListRow);

    return friend1.fr.status - friend2.fr.status;
  }

  public void remove_friend (Tox.Friend fr) {
    var friend = (this.friends.get_object (fr.position) as Tox.Friend);
    var dialog = new Gtk.MessageDialog (this,
                                        Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION, Gtk.ButtonsType.NONE,
                                        @"Are you sure you want to delete \"$(friend.name)\"?");
    dialog.secondary_text = @"This will remove \"$(friend.name)\" and the chat history with it forever.";
    dialog.add_buttons ("Yes", Gtk.ResponseType.ACCEPT, "No", Gtk.ResponseType.REJECT);
    dialog.response.connect (response => {
      if (response == Gtk.ResponseType.ACCEPT) {
        bool result = friend.delete ();
        if (result) {
          this.friends.remove (friend.position);
          this.tox.save_data ();
        }
      }

      dialog.destroy ();
    });

    dialog.show ();
  }

  public MainWindow (Gtk.Application app, string profile) {
    Object (application: app);

    var opts = Tox.Options.create ();
    opts.ipv6_enabled = true;
    opts.udp_enabled = true;

    try {
      this.tox = new Tox.Tox (opts, profile);
    } catch (Tox.ErrNew error) {
      warning ("Tox init failed: %s", error.message);
      this.destroy ();
      var error_dialog = new Gtk.MessageDialog (null,
          Gtk.DialogFlags.MODAL,
          Gtk.MessageType.WARNING,
          Gtk.ButtonsType.OK,
          "Can't load the profile");
      error_dialog.secondary_use_markup = true;
      error_dialog.format_secondary_markup (@"<span color=\"#e74c3c\">$(error.message)</span>");
      error_dialog.response.connect (resp => error_dialog.destroy ()); // if we don't use a signal the profile chooser closes
      error_dialog.show ();
      return;
    }

    paned_header.bind_property ("position", paned_main, "position", BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);

    // window title = "headebar title - Ricin"
    headerbar_right.bind_property ("title", this, "title", BindingFlags.SYNC_CREATE, (bind, src, ref target) => {
      target = @"$(src.get_string ()) \u2015 Ricin";
      return true;
    });

    // update headerbar title
    this.chat_stack.notify["visible-child"].connect ((obj, prop) => {
      var widget = this.chat_stack.visible_child;
      button_call.visible = false;
      button_video_chat.visible = false;
      if (widget != null) {
        headerbar_right.title = widget.name;

        if (widget is ChatView) {
          button_call.visible = true;
          button_video_chat.visible = true;
        }
      }
    });

    // Display the settings window while their is no friends online.
    var settings = new SettingsView (this.tox);
    this.chat_stack.add_named (settings, settings.name);

    var path = avatar_path ();
    if (FileUtils.test (path, FileTest.EXISTS)) {
      tox.send_avatar (path);
      var pixbuf = new Gdk.Pixbuf.from_file_at_scale (path, 48, 48, false);
      this.avatar_image.pixbuf = pixbuf;
    }

    // TODO
    this.entry_name.set_text (tox.username);
    this.entry_status.set_text (tox.status_message);
    this.friendlist.set_sort_func (sort_friendlist_online);

    this.friendlist.bind_model (this.friends, fr => new FriendListRow (fr as Tox.Friend, this));

    this.entry_status.bind_property ("text", tox, "status_message", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);

    tox.notify["connected"].connect ((src, prop) => {
      this.image_user_status.icon_name = this.tox.connected ? "user-available" : "user-offline";
      this.button_user_status.sensitive = this.tox.connected;
    });

    this.tox.friend_request.connect ((id, message) => {
      var dialog = new Gtk.MessageDialog (this, Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION, Gtk.ButtonsType.NONE, "Friend request from:");
      dialog.secondary_text = @"$id\n\n$message";
      dialog.add_buttons ("Accept", Gtk.ResponseType.ACCEPT, "Reject", Gtk.ResponseType.REJECT);
      dialog.response.connect (response => {
        if (response == Gtk.ResponseType.ACCEPT) {
          var friend = tox.accept_friend_request (id);
          if (friend != null) {
            this.tox.save_data (); // Needed to avoid breaking profiles if app crash.

            friend.position = friends.get_n_items ();
            debug ("Friend position: %u", friend.position);
            friends.append (friend);
            var view_name = "chat-%s".printf (friend.pubkey);
            var chatview = new ChatView (this.tox, friend, this.chat_stack, view_name);
            chat_stack.add_named (chatview, chatview.name);

            var info_message = "The friend request has been accepted. Please wait the contact to appears online.";
            this.notify_message (@"<span color=\"#27ae60\">$info_message</span>", 5000);
          }
        }
        dialog.destroy ();
      });
      dialog.show ();
    });

    this.tox.friend_online.connect ((friend) => {
      if (friend != null) {
        friend.position = friends.get_n_items ();
        debug ("Friend position: %u", friend.position);
        friends.append (friend);
        var view_name = "chat-%s".printf (friend.pubkey);
        chat_stack.add_named (new ChatView (this.tox, friend, this.chat_stack, view_name), view_name);

        // Send our avatar.
        friend.send_avatar ();
      }
    });

    this.notify_message.connect ((message, timeout) =>  {
      this.label_system_notify.use_markup = true;
      this.label_system_notify.set_markup (message);
      this.revealer_system_notify.reveal_child = true;
      Timeout.add (timeout, () => {
        this.revealer_system_notify.reveal_child = false;
        return Source.REMOVE;
      });
    });

    this.tox.run_loop ();
    this.show ();
  }

  ~MainWindow () {
    this.tox.save_data ();
  }

  public void show_add_friend_popover_with_text (string toxid = "", string message = "") {
    var friend_message = "";

    if (message.strip () == "") {
      friend_message = "Hello! It's " + this.tox.username + ", let's be friends.";
    }

    this.entry_friend_id.set_text (toxid);
    this.entry_friend_message.buffer.text = friend_message;
    this.button_add_friend_show.visible = false;
    this.add_friend.reveal_child = true;
  }

  [GtkCallback]
  private void show_settings () {
    var settings_view = this.chat_stack.get_child_by_name ("settings");

    if (settings_view != null) {
      this.chat_stack.set_visible_child (settings_view);
    } else {
      var view = new SettingsView (tox);
      this.chat_stack.add_named (view, "settings");
      this.chat_stack.set_visible_child (view);
      this.focused_view = "settings";
    }
  }

  [GtkCallback]
  public void show_add_friend_popover () {
    this.show_add_friend_popover_with_text ();
  }

  [GtkCallback]
  private void hide_add_friend_popover () {
    this.add_friend.reveal_child = false;
    this.label_add_error.set_text ("Add a friend");
    this.button_add_friend_show.visible = true;
  }

  [GtkCallback]
  private void ui_add_friend () {
    debug ("add_friend");
    var tox_id = this.entry_friend_id.get_text ();
    var message = this.entry_friend_message.buffer.text;
    var error_message = "";
    this.label_add_error.use_markup = true;
    this.label_add_error.use_markup = true;
    this.label_add_error.halign = Gtk.Align.CENTER;
    this.label_add_error.wrap_mode = Pango.WrapMode.CHAR;
    this.label_add_error.selectable = true;
    this.label_add_error.set_line_wrap (true);

    if (tox_id.length == ToxCore.ADDRESS_SIZE*2) { // bytes -> chars
      try {
        var friend = tox.add_friend (tox_id, message);
        this.tox.save_data (); // Needed to avoid breaking profiles if app crash.
        this.entry_friend_id.set_text (""); // Clear the entry after adding a friend.
        this.add_friend.reveal_child = false;
        this.label_add_error.set_text ("Add a friend");
        this.button_add_friend_show.visible = true;
        return;
      } catch (Tox.ErrFriendAdd error) {
        debug ("Adding friend failed: %s", error.message);
        error_message = error.message;
      }
    } else if (tox_id.index_of ("@") != -1) {
      error_message = "Ricin doesn't supports ToxDNS yet.";
    } else if (tox_id.strip () == "") {
      error_message = "ToxID can't be empty.";
    } else {
      error_message = "ToxID is invalid.";
    }

    if (error_message.strip () != "") {
      this.label_add_error.set_markup (@"<span color=\"#e74c3c\">$error_message</span>");
      return;
    }

    this.add_friend.reveal_child = false;
    this.button_add_friend_show.visible = true;
  }

  [GtkCallback]
  private void show_friend_chatview (Gtk.ListBoxRow row) {
    var friend = (row as FriendListRow).fr;
    var view_name = "chat-%s".printf (friend.pubkey);
    var chat_view = this.chat_stack.get_child_by_name (view_name);
    debug ("ChatView name: %s", view_name);

    if (chat_view != null) {
      (chat_view as ChatView).entry.grab_focus ();
      this.chat_stack.set_visible_child (chat_view);
    }
  }

  [GtkCallback]
  private void set_username_from_entry () {
    this.tox.username = Util.escape_html (this.entry_name.text);
  }

  [GtkCallback]
  private void cycle_user_status () {
    var status = this.tox.status;
    switch (status) {
      case Tox.UserStatus.ONLINE:
        // Set status to away.
        this.tox.status = Tox.UserStatus.AWAY;
        this.image_user_status.icon_name = "user-away";
        break;
      case Tox.UserStatus.AWAY:
        // Set status to busy.
        this.tox.status = Tox.UserStatus.BUSY;
        this.image_user_status.icon_name = "user-busy";
        break;
      case Tox.UserStatus.BUSY:
        // Set status to online.
        this.tox.status = Tox.UserStatus.ONLINE;
        this.image_user_status.icon_name = "user-available";
        break;
      default:
        this.image_user_status.icon_name = "user-offline";
        break;
    }
  }

  [GtkCallback]
  private void choose_avatar () {
    var chooser = new Gtk.FileChooserDialog ("Select your avatar",
        this,
        Gtk.FileChooserAction.OPEN,
        "_Cancel", Gtk.ResponseType.CANCEL,
        "_Open", Gtk.ResponseType.ACCEPT);
    var filter = new Gtk.FileFilter ();
    filter.add_custom (Gtk.FileFilterFlags.MIME_TYPE, info => {
      var mime = info.mime_type;
      return mime.has_prefix ("image/") && mime != "image/gif";
    });
    chooser.filter = filter;
    if (chooser.run () == Gtk.ResponseType.ACCEPT) {
      File avatar = chooser.get_file ();
      this.tox.send_avatar (avatar.get_path ());
      this.avatar_image.pixbuf = new Gdk.Pixbuf.from_file_at_scale (avatar.get_path (), 46, 46, true);

      // Copy avatar to ~/.config/tox/avatars/
      try {
        avatar.copy (File.new_for_path (this.avatar_path ()), FileCopyFlags.OVERWRITE);
      } catch (Error err) {
        warning ("Cannot save the avatar in cache: %s", err.message);
      }
    }

    chooser.close ();
  }
}
