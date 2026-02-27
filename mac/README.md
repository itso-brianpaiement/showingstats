## Showing System Member Count - macOS

### 1) Download
1. On GitHub, click **Code**.
2. Click **Download ZIP**.
3. Save the ZIP to Desktop (or anywhere you want).

### 2) Unzip
1. Double-click the ZIP file, or right-click and choose **Open**.
2. Open the extracted folder.
3. Open the `mac` folder.

### 3) Get your Bridge API values and paste them into `keys`
1. Open a browser tab and go to `https://bridgedataoutput.com/`.
2. Log in to Bridge.
3. At the top, click **API Access**.
4. Copy your API values from that page.
5. Open the `keys` file in TextEdit.
6. Leave the first line exactly as: `Endpoint URL: itso`.
7. Replace only the `REPLACE_THIS_WITH_...` values with your real Bridge values.
8. Save and close the file.

### 4) Run the report
1. Double-click `CLICK ME TO GENERATE.command`.
2. If macOS blocks it, right-click it and choose **Open**, then click **Open**.
3. Wait for it to finish.

### 5) Find your output
The script creates:

- `output/Month_dd_ShowingSystemStats/`

Inside that folder:
- `data/` (raw data files)
- `Showing_System_Member_Count_Month.csv` (finished report)

### Important
- Do not share the `keys` file publicly. It contains private API credentials.
