## Showing System Member Count - Simple Instructions

### 1) Download
1. At the top right of this page click **Code**.
2. Click **Download ZIP**.
3. Save the ZIP to your Desktop (or any folder you prefer).

### 2) Unzip the folder
1. Right-click the ZIP file.
2. Click **Extract All...**.
3. Choose where you want the files.
4. Click **Extract**.
5. Open the extracted folder, then open the `windows` folder.

You should now have a normal folder with these files inside, including:
- `keys`
- `CLICK ME TO GENERATE.cmd`

### 3) Get your Bridge API values and paste them into `keys`
1. Open a new browser tab and go to `https://bridgedataoutput.com/`.
2. Log in to Bridge.
3. At the top, click **API Access**.
4. Copy your API values from that page.
5. In your downloaded folder, right-click the file named **keys**.
6. Click **Open with** > **Notepad**.
7. Leave the first line exactly as: `Endpoint URL: itso`.
8. Replace only the `REPLACE_THIS_WITH_...` values on the other lines with your real Bridge values.
9. Do not change the labels on the left side.
10. Click **File** > **Save** and close Notepad.

Example:
- `Client ID: REPLACE_THIS_WITH_CLIENT_ID_FROM_BRIDGE` -> `Client ID: <your real Client ID>`

### 4) Run the report
1. Right-click **CLICK ME TO GENERATE.cmd**.
2. Click **Run as administrator**.
3. When Windows asks for permission, click **Yes**.
4. Wait for it to finish.

### 5) Find your output files
The script creates a folder like:

- `output\February_27_ShowingSystemStats\`

Inside that folder:
- `data\` (raw data files)
- `Showing_System_Member_Count_February.csv` (your finished report)

### Important
- Do not share the `keys` file publicly. It contains private API credentials.
