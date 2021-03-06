/* -*- Mode: vala; tab-width: 4; intend-tabs-mode: t -*- */
/* PSNotes
 *
 * Copyright (C) Zach Burnham 2012 <thejambi@gmail.com>
 *
PSNotes is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * PSNotes is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gee;

public class UserSettingsManager : GLib.Object {

	private KeyFile keyFile;

	private string psNotesConfPath;

	public static const string notesDirKey = "notesDirectory";
	public static const string notesDirGroup = "PSNotes";
	public static const string notebooksGroup = "Notebooks";
	
	public static const string windowWidthKey = "width";
	public static const string windowHeightKey = "height";
	public static const string panePositionKey = "panePosition";
	public static const string marginsKey = "margins";
	public static const string showWordCountKey = "showWordCount";
	public static const string fontKey = "font";
	public static const string altSortTypeKey = "alternateSortType";
	public static const string fileExtKey = "fileExtension";

	// Constructor
	public UserSettingsManager () {
		// Make sure the settings folder exists
		string settingsDirPath = UserData.homeDirPath + "/.config/psnotes";
		FileUtility.createFolder(settingsDirPath);

		// Get path to dayjournal.conf file
		this.psNotesConfPath = settingsDirPath + "/psnotes.conf";

		// Make sure that settings files exist
		File settingsFile = File.new_for_path(this.psNotesConfPath);

		if (!settingsFile.query_exists()) {
			try {
				settingsFile.create(FileCreateFlags.NONE);
			} catch(Error e) {
				stderr.printf ("Error creating settings file: %s\n", e.message);
			}
		}

		// Initialize variables
		keyFile = new KeyFile();

		try {
			keyFile.load_from_file(this.psNotesConfPath, 0);
		} catch(Error e) {
			stderr.printf ("Error in UserSettingsManager(): %s\n", e.message);
		}

		// Process keyFile and save keyFile to disk if needed
		if (processKeyFile()) {
			this.writeKeyFile();
		}
	}

	/**
	 * Process the key file. Return true if keyFile needs to be written.
	 */
	private bool processKeyFile() {
		string originalKeyFileData = keyFile.to_data();

		try {
			UserData.notesDirPath = keyFile.get_string(this.notesDirGroup, this.notesDirKey);
			Zystem.debug("Got notes dir path");
		} catch (KeyFileError e) {
			// Set default
			UserData.notesDirPath = UserData.getDefaultNotesDir();
			Zystem.debug("Gotta use the default...");
		}

		try {
			UserData.useAltSortType = keyFile.get_boolean(this.notesDirGroup, this.altSortTypeKey);
			Zystem.debug("Got sort type alpha");
		} catch (KeyFileError e) {
			// Set default
			UserData.useAltSortType = false;
		}

		try {
			UserData.showWordCount = keyFile.get_boolean(notesDirGroup, showWordCountKey);
		} catch (KeyFileError e) {
			// Set default
			UserData.showWordCount = true;
		}

		try {
			UserData.fontString = keyFile.get_string(notesDirGroup, fontKey);
		} catch (KeyFileError e) {
			UserData.fontString = "";
		}

		try {
			UserData.fileExtension = keyFile.get_string(notesDirGroup, fileExtKey);
		} catch (KeyFileError e) {
			UserData.fileExtension = UserData.fileExtTxt;
		}

		try {
			UserData.windowWidth = keyFile.get_integer(this.notesDirGroup, this.windowWidthKey);
			UserData.windowHeight = keyFile.get_integer(this.notesDirGroup, this.windowHeightKey);
			UserData.panePosition = keyFile.get_integer(this.notesDirGroup, this.panePositionKey);
			UserData.defaultMargins = keyFile.get_integer(this.notesDirGroup, this.marginsKey);
		} catch (KeyFileError e) {
			Zystem.debug("Error loading window size; using default.");
		}

		// Return true if the keyFile data has been updated (if it's no longer the same as it was)
		return originalKeyFileData != keyFile.to_data();
	}

	/**
	 * Write settings file.
	 */
	private void writeKeyFile() {
		try {
			FileUtils.set_contents(this.psNotesConfPath, this.keyFile.to_data());
		} catch(Error e) {
			stderr.printf("Error writing keyFile: %s\n", e.message);
		}
	}

	public void setNotesDir(string path) {
		keyFile.set_string(this.notesDirGroup, this.notesDirKey, path);
		writeKeyFile();
	}

	public void setInt(string key, int val) {
		keyFile.set_integer(notesDirGroup, key, val);
		writeKeyFile();
	}

	public void setBool(string key, bool val) {
		keyFile.set_boolean(notesDirGroup, key, val);
	}

	public void setString(string key, string val) {
		keyFile.set_string(notesDirGroup, key, val);
	}

	public void addNotebook(string name, string path) {
		keyFile.set_string(notebooksGroup, name, path);
		writeKeyFile();
	}

	public void removeNotebook(string name) {
		keyFile.remove_key(this.notebooksGroup, name);
		writeKeyFile();
	}

	public ArrayList<string> getNotebookList() {
		var list = new ArrayList<string>();

		foreach (string s in keyFile.get_keys(notebooksGroup)) {
			list.add(s);
		}

		return list;
	}

}
