[GtkTemplate (ui="/chat/tox/ricin/ui/message-list-row.ui")]
class Ricin.MessageListRow : Gtk.ListBoxRow {
  [GtkChild] Gtk.Label label_name;
  [GtkChild] Gtk.Label label_message;
  [GtkChild] Gtk.Spinner spinner_read;
  [GtkChild] Gtk.Label label_timestamp;

  private uint position;
  private uint32 message_id;
  public bool is_child = false;

  private weak Tox.Tox handle;
  private weak Tox.Friend sender;

  public MessageListRow (Tox.Tox handle, Tox.Friend? sender, string message, string timestamp, uint32 message_id, bool is_child) {
    this.handle = handle;
    this.message_id = message_id;
    this.sender = sender;
    this.is_child = is_child;
    string name = "";

    if (this.sender == null) {
      name = Util.escape_html (this.handle.username);
      this.label_name.set_markup ("<b>" + name + "</b>");

      this.handle.bind_property ("username", label_name, "label", BindingFlags.DEFAULT);
      this.handle.message_read.connect ((friend_num, message_id) => {
        if (message_id != this.message_id) {
          return;
        }

        this.spinner_read.visible = false;
      });
    } else {
      name = Util.escape_html (this.sender.name);
      this.label_name.set_text (name);
      this.spinner_read.visible = false;
    }

    if (this.is_child) {
      // Don't display name for childs.
      this.label_name.set_text (" ");
    }

    /**
    * TEMP DEV ZONE:
    * EMOJI SUPPORT.
    **/
    var msg = message;
    /**
    * TEMP DEV ZONE:
    * EMOJI SUPPORT.
    **/

    this.label_name.set_markup (@"<b>$name</b>");
    this.label_message.set_markup (msg);
    this.label_timestamp.set_text (timestamp);

    this.label_message.activate_link.connect (this.handle_links);

    /**
    * Keep the name in sync.
    */

    // If message is our (ugly&hacky way).
    if (this.handle.username == name) {
      this.handle.bind_property ("username", label_name, "label", BindingFlags.DEFAULT);
      this.handle.message_read.connect ((friend_num, message_id) => {
        if (message_id != this.message_id) {
          return;
        }

        this.spinner_read.visible = false;
      });
    } else {
      this.spinner_read.visible = false;
    }
  }

  private bool handle_links (string uri) {
    if (!uri.has_prefix ("tox:")) {
      return false; // Default behavior.
    }

    var main_window = this.get_toplevel () as MainWindow;
    var toxid = uri.split ("tox:")[1];
    if (toxid.length == ToxCore.ADDRESS_SIZE * 2) {
      main_window.show_add_friend_popover_with_text (toxid);
    } else {
      var info_message = _("ToxDNS is not supported yet.");
      main_window.notify_message (@"<span color=\"#e74c3c\">$info_message</span>");
    }

    return true;
  }
}
