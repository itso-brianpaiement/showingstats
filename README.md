## Showing System Member Count - Instructions (Windows and Mac)

### 1) Download
1. Open this GitHub page.
2. Click **Code**.
3. Click **Download ZIP**.
4. Save the ZIP to your Desktop (or anywhere you want).

### 2) Unzip the folder
1. Unzip the ZIP file.
Windows: Right-click ZIP > **Extract All...**
Mac: Double-click ZIP (or right-click > **Open**).
2. Open the extracted folder.
3. Open the folder for your computer:
- `windows` (if you are on Windows)
- `mac` (if you are on Mac)

### 3) Add your Bridge API values in `keys`
1. Open a browser tab and go to `https://bridgedataoutput.com/`.
2. Log in to Bridge.
3. Click **API Access** at the top.
4. Copy your API values from that page.
5. Open the `keys` file in your platform folder.
Windows: Right-click `keys` > **Open with** > **Notepad**
Mac: Open `keys` in TextEdit
6. Leave the first line exactly as:
`Endpoint URL: itso`
7. Replace only the `REPLACE_THIS_WITH_...` values with your real Bridge values.
8. Save and close the file.

Example:
- `Client ID: REPLACE_THIS_WITH_CLIENT_ID_FROM_BRIDGE`
- Replace only the part after `Client ID:` with your real Client ID.

### 4) Run the report
Windows:
1. Double-click `CLICK ME TO GENERATE.cmd`
2. If Windows warns about unknown publisher, click **More info** then **Run anyway**

Mac:
1. Double-click `CLICK ME TO GENERATE.command`
2. If blocked, right-click it and choose **Open**, then click **Open**

### 5) Find your output files
The script creates an output folder like:

- `output/February_27_ShowingSystemStats/`

Inside:
- `data/` (raw data files)
- `Showing_System_Member_Count_February.csv` (final report)

### Notes
- Do not share the `keys` file publicly. It contains private API credentials.
- The Mac launcher does not require PowerShell.
- Windows and Mac steps are the same except:
  - Which folder you open (`windows` vs `mac`)
  - Which launcher you run (`.cmd` vs `.command`)
  - The security warning screen style
