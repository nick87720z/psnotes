/* -*- Mode: C; indent-tabs-mode: t; c-basic-offset: 4; tab-width: 4 -*- */
/*
 * main.c
 * Copyright (C) 2012 Zach Burnham <thejambi@gmail.com>
 * 
 * P.S.Notes is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * P.S.Notes is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;

public class Main : Window {

	// SET THIS TO TRUE BEFORE BUILDING TARBALL
	private const bool isInstalled = true;

	private const string shortcutsText = 
			"Ctrl+N: Create a new note\n" + 
			"Ctrl+O: Choose notes folder\n" + 
			"Ctrl+=: Increase font size\n" + 
			"Ctrl+-: Decrease font size\n" + 
			"Ctrl+0: Reset font size";

	private Note note;

	private int startingFontSize;
	private int fontSize;

	private string lastKeyName;

	private bool needsSave = false;
	private bool isOpening = false;
	private bool loadingNotes = false;
	private bool firstLaunch = true;

	private Entry txtFilter;
	private TreeView notesView;
	private TextView noteTextView;
	private NoteEditor editor;

	/** 
	 * Constructor for main P.S. Notes window.
	 */
	public Main() {

		Zystem.debugOn = !isInstalled;

		UserData.initializeUserData();

		this.lastKeyName = "";

		this.title = "P.S. Notes.";
		this.window_position = WindowPosition.CENTER;
		set_default_size(530, 400);

		// Create menu
		var menubar = new MenuBar();
		
		// Set up Notes menu
		var notesMenu = new Menu();
		var menuNewNote = new MenuItem.with_label("New Note");
		menuNewNote.activate.connect(() => {
			this.createNewNote();
		});
		var menuChangeNotesDir = new MenuItem.with_label("Change Notes Folder");
		menuChangeNotesDir.activate.connect(() => {
			changeNotesDir();
		});
		var menuOpenNotesLocation = new MenuItem.with_label("View Notes Files");
		menuOpenNotesLocation.activate.connect(() => {
			openNotesLocation();
		});
		var menuClose = new MenuItem.with_label("Close P.S. Notes.");
		menuClose.activate.connect(() => {
			this.on_destroy();
		});
		notesMenu.append(menuNewNote);
		notesMenu.append(menuChangeNotesDir);
		notesMenu.append(menuOpenNotesLocation);
		notesMenu.append(new SeparatorMenuItem());
		notesMenu.append(menuClose);

		MenuItem notesMenuItem = new MenuItem.with_label("Notes");
		notesMenuItem.set_submenu(notesMenu);
		menubar.append(notesMenuItem);

		// Set up Settings menu
		var settingsMenu = new Menu();
		var menuIncreaseFontSize = new MenuItem.with_label("Increase font size");
		menuIncreaseFontSize.activate.connect(() => {
			this.increaseFontSize();
		});
		var menuDecreaseFontSize = new MenuItem.with_label("Decrease font size");
		menuDecreaseFontSize.activate.connect(() => {
			this.decreaseFontSize();
		});
		// var menuUnlockEntry = new MenuItem.with_label("Unlock entry");
		// menuUnlockEntry.activate.connect(() => { this.unlockEntry(); });
		// settingsMenu.append(menuUnlockEntry);
		settingsMenu.append(menuIncreaseFontSize);
		settingsMenu.append(menuDecreaseFontSize);

		MenuItem settingsMenuItem = new MenuItem.with_label("Settings");
		settingsMenuItem.set_submenu(settingsMenu);
		menubar.append(settingsMenuItem);

		// Set up Help menu
		var helpMenu = new Menu();
		var menuKeyboardShortcuts = new MenuItem.with_label("Keyboard Shortcuts");
		menuKeyboardShortcuts.activate.connect(() => {
			showKeyboardShortcuts();
		});
		var menuAbout = new MenuItem.with_label("About P.S. Notes.");
		menuAbout.activate.connect(() => {
			this.menuAboutClicked();
		});
		helpMenu.append(menuKeyboardShortcuts);
		helpMenu.append(menuAbout);

		MenuItem helpMenuItem = new MenuItem.with_label("Help");
		helpMenuItem.set_submenu(helpMenu);
		menubar.append(helpMenuItem);

		this.txtFilter = new Entry();

		this.notesView = new TreeView();
		this.setupNotesView();

		this.noteTextView = new TextView();

		this.noteTextView.buffer.changed.connect(() => {
			onTextChanged(this.noteTextView.buffer);
		});
		this.editor = new NoteEditor(this.noteTextView.buffer);
		this.noteTextView.pixels_above_lines = 2;
		this.noteTextView.pixels_below_lines = 2;
		this.noteTextView.pixels_inside_wrap = 4;
		this.noteTextView.wrap_mode = WrapMode.WORD_CHAR;
		this.noteTextView.left_margin = 4;
		this.noteTextView.right_margin = 4;
		this.noteTextView.accepts_tab = true;

		var scroll1 = new ScrolledWindow (null, null);
		// scroll1.shadow_type = ShadowType.ETCHED_OUT;
		scroll1.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
		scroll1.min_content_width = 160;
		// scroll1.min_content_height = 280;
		scroll1.add (this.notesView);
		scroll1.expand = true;

		var vbox = new Box(Orientation.VERTICAL, 2);
		// vbox.pack_start(txtFilter, false, true, 2);
		// vbox.pack_start(this.notesView, true, true, 2);
		vbox.pack_start(scroll1, true, true, 2);

		var scroll = new ScrolledWindow (null, null);
		scroll.shadow_type = ShadowType.ETCHED_OUT;
		scroll.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
		scroll.min_content_width = 251;
		scroll.min_content_height = 280;
		scroll.add (this.noteTextView);
		scroll.expand = true;

		var paned = new Paned(Orientation.HORIZONTAL);
		paned.add1(vbox);
		paned.add2(scroll);

		var vbox1 = new Box (Orientation.VERTICAL, 0);
		vbox1.pack_start(menubar, false, true, 0);
		vbox1.pack_start (paned, true, true, 2);

		add (vbox1);

		this.startingFontSize = 10;
		this.fontSize = startingFontSize;
		this.resetFontSize();

		// Connect keypress signal
		this.key_press_event.connect((window,event) => { 
			return this.onKeyPress(event); 
		});

		this.destroy.connect(() => { this.on_destroy(); });
	}

	private void setupNotesView() {
		var listmodel = new ListStore (1, typeof (string));
		this.notesView.set_model (listmodel);

		this.notesView.insert_column_with_attributes (-1, "Notes", new CellRendererText (), "text", 0);

		this.loadNotesList();

		var treeSelection = this.notesView.get_selection();
		treeSelection.set_mode(SelectionMode.SINGLE);
		treeSelection.changed.connect(() => {
			noteSelected(treeSelection);
		});
	}

	private void loadNotesList() {
		this.loadingNotes = true;

		try {
			var listmodel = this.notesView.model as ListStore;
			listmodel.clear();
			listmodel.set_sort_column_id(0, SortType.ASCENDING);
			var notesList = new GLib.List<string>();
			TreeIter iter;

			File notesDir = File.new_for_path(UserData.notesDirPath);
			FileEnumerator enumerator = notesDir.enumerate_children(FILE_ATTRIBUTE_STANDARD_NAME, 0);
			FileInfo fileInfo;

			// Go through the files
			while((fileInfo = enumerator.next_file()) != null) {
				string filename = fileInfo.get_name();
				if (FileUtility.getFileExtension(fileInfo) == ".txt") {
					Zystem.debug(FileUtility.getFileNameWithoutExtension(fileInfo));
					listmodel.append(out iter);
					listmodel.set(iter, 0, FileUtility.getFileNameWithoutExtension(fileInfo));
				}
			}
		} catch(Error e) {
			stderr.printf ("Error loading notes list: %s\n", e.message);
		}

		this.loadingNotes = false;
	}

	private void noteSelected(TreeSelection treeSelection) {
		if (this.firstLaunch) {
			treeSelection.unselect_all();
			this.noteTextView.is_focus = true;
			this.firstLaunch = false;
			return;
		}
		if (this.loadingNotes) {
			return;
		}

		if (this.note != null) {
			this.seldomSave();
		}

		TreeModel model;
		TreeIter iter;
		treeSelection.get_selected(out model, out iter);
		Value value;
		model.get_value(iter, 0, out value);
		Zystem.debug("SELECTION IS: " + value.get_string());

		string noteTitle = value.get_string();
		
		this.isOpening = true;

		this.note = new Note(noteTitle);
		this.editor.startNewNote(this.note.getContents());
		this.needsSave = false;

		this.isOpening = false;
	}

	public bool onKeyPress(Gdk.EventKey key) {
		uint keyval;
        keyval = key.keyval;
		Gdk.ModifierType state;
		state = key.state;
		bool ctrl = (state & Gdk.ModifierType.CONTROL_MASK) != 0;
		bool shift = (state & Gdk.ModifierType.SHIFT_MASK) != 0;

		string keyName = Gdk.keyval_name(keyval);
		
		// Zystem.debug("Key:\t" + keyName);

		if (ctrl && shift) { // Ctrl+Shift+?
			Zystem.debug("Ctrl+Shift+" + keyName);
			switch (keyName) {
				case "Z":
					// this.editor.redo();
					Zystem.debug("Y'all hit Ctrl+Shift+Z");
					break;
				default:
					Zystem.debug("What should Ctrl+Shift+" + keyName + " do?");
					break;
			}
		}
		else if (ctrl) { // Ctrl+?
			switch (keyName) {
				case "z":
					// this.editor.undo();
					break;
				case "y":
					// this.editor.redo();
					break;
				case "d":
					// this.editor.prependDateToEntry(this.entry.getEntryDateHeading());
					break;
				case "n":
					this.createNewNote();
					break;
				case "o":
					this.changeNotesDir();
					break;
				case "equal":
					this.increaseFontSize();
					break;
				case "minus":
					this.decreaseFontSize();
					break;
				case "0":
					this.resetFontSize();
					break;
				default:
					Zystem.debug("What should Ctrl+" + keyName + " do?");
					break;
			}
		}
		else if (!(ctrl || shift || keyName == this.lastKeyName)) { // Just the one key
			switch (keyName) {
				case "period":
				case "Return":
				case "space":
					this.seldomSave();
					break;
				default:
					break;
			}
		}

		this.lastKeyName = keyName;
		
		// Return false or the entry does not get updated.
		return false;
	}

	public void onTextChanged(TextBuffer buffer) {
		if (!this.isOpening) {
			this.needsSave = true;
		} else {
			return;
		}

		// If creating a new note
		if (this.note == null && this.editor.getText() != "") {
			Zystem.debug("NOTE IS NULL, thank you very much!");
			Zystem.debug("Note title should be: " + this.editor.firstLine());
			this.note = new Note(this.editor.firstLine().strip());
			this.loadNotesList();
		}

		Zystem.debug("PAY ATTENTIONS TO MEEEEEEEEEEEEEE " + this.editor.firstLine().strip());

		// If note title changed
		if (this.editor.lineCount() > 0 && this.editor.firstLine().strip() != ""
				&& this.noteTitleChanged()) {
			Zystem.debug("Oh boy, the note title changed. Let's rename that sucker.");
			this.note.rename(this.editor.firstLine().strip(), this.editor.getText());
			this.loadNotesList();
		}

		if (this.editor.firstLine().strip() == "") {
			this.seldomSave();
		}

		if (this.editor.lineCount() == 0 || this.editor.firstLine().strip() == "") {
			this.loadNotesList();
		}
	}

	private bool noteTitleChanged() {
		if (this.editor.lineCount() == 0) {
			return false;
		}

		return this.editor.firstLine().strip() != this.note.title;
	}

	private void createNewNote() {
		this.note = new Note("NEW NOTE");
		this.loadNotesList();
		this.needsSave = true;
		this.editor.startNewNote(this.note.title);
		this.noteTextView.select_all(true);
	}

	/**
	 * Font size methods
	 */
	private void resetFontSize() {
		this.changeFontSize(this.startingFontSize - this.fontSize);
	}

	private void increaseFontSize() {
		this.changeFontSize(1);
	}
	private void decreaseFontSize() {
		this.changeFontSize(-1);
	}

	private void changeFontSize(int byThisMuch) {
		// If font would be too small or too big, no way man
		if (this.fontSize + byThisMuch < 6 || this.fontSize + byThisMuch > 50) {
			Zystem.debug("Not changing font size, because it would be: " + this.fontSize.to_string());
			return;
		}

		this.fontSize += byThisMuch;
		Zystem.debug("Changing font size to: " + this.fontSize.to_string());

		Pango.FontDescription font = this.noteTextView.style.context.get_font(StateFlags.NORMAL);
		double newFontSize = (this.fontSize) * Pango.SCALE;
		font.set_size((int)newFontSize);
		this.noteTextView.modify_font(font);
	}

	private async void seldomSave() {
		Zystem.debug("THIS IS A SELDOM SAVE POINT AND needsSave is " + this.needsSave.to_string());
		if (UserData.seldomSave && this.needsSave) {
			this.callSave();
		}
	}

	private async void callSave() {
		try {
			this.note.save(this.editor.getText());
			this.needsSave = false;
		} catch (Error e) {
			Zystem.debug("There was an error saving the file.");
		}
	}

	public void changeNotesDir() {
		Zystem.debug("Changing Notes dir eh?");

		var fileChooser = new FileChooserDialog("Choose Notes Folder", this,
												FileChooserAction.SELECT_FOLDER,
												Stock.CANCEL, ResponseType.CANCEL,
												Stock.OPEN, ResponseType.ACCEPT);
		if (fileChooser.run() == ResponseType.ACCEPT) {
			string dirPath = fileChooser.get_filename();
			UserData.setNotesDir(dirPath);
			// this.setDjDirLocationMenuLabel();
			// Open new entry for the selected date from the new location
			this.loadNotesList();
		}
		fileChooser.destroy();
	}

	private void openNotesLocation() {
		Gtk.show_uri(null, "file://" + UserData.notesDirPath, Gdk.CURRENT_TIME);
	}

	private void showKeyboardShortcuts() {
		var dialog = new Gtk.MessageDialog(null,Gtk.DialogFlags.MODAL,Gtk.MessageType.INFO, 
						Gtk.ButtonsType.OK, this.shortcutsText);
		dialog.set_title("Message Dialog");
		dialog.run();
		dialog.destroy();
	}

	private void menuAboutClicked() {
		var about = new AboutDialog();
		about.set_program_name("P.S. Notes.");
		about.comments = "Notes, plain and simple.";
		about.website = "http://zburnham.co.cc/";
		about.logo_icon_name = "psnotes";
		about.set_copyright("by Zach Burnham");
		about.run();
		about.hide();
	}

	/**
	 * Quit DayNotes.
	 */
	public void on_destroy () {
		if (UserData.seldomSave && this.needsSave) {
			Zystem.debug("Saving file on exit.");
			this.callSave();
			// try {
			// 	this.note.saveNonAsync(this.editor.getText());
			// } catch (Error e) {
			// 	Zystem.debug("There was an error saving the file.");
			// }
		}
		Gtk.main_quit();
	}

	public static int main(string[] args) {
		Gtk.init(ref args);

		var window = new Main();
		window.destroy.connect(Gtk.main_quit);
		window.show_all();

		Gtk.main();
		return 0;
	}
}