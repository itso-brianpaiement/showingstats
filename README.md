## Showing System Member Count - Simple Instructions

### 1) Download from GitHub
1. Open the GitHub page for this project.
2. Click **Code**.
3. Click **Download ZIP**.
4. Save the ZIP to your Desktop (or any folder you prefer).

### 2) Unzip the folder
1. Right-click the ZIP file.
2. Click **Extract All...**.
3. Choose where you want the files.
4. Click **Extract**.

You should now have a normal folder with these files inside, including:
- `keys`
- `CLICK ME TO GENERATE.cmd`

### 3) Add your Bridge API info
1. Right-click the file named **keys**.
2. Click **Open with** > **Notepad**.
3. Enter your Bridge API values in that file.
4. Click **File** > **Save**.
5. Close Notepad.

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

### If Windows blocks the file
If Smart App Control or Windows blocks the script:
1. Right-click the downloaded ZIP file.
2. Click **Properties**.
3. If you see **Unblock**, check it.
4. Click **Apply** and **OK**.
5. Extract the ZIP again and run it.

### Important
- Do not share the `keys` file publicly. It contains private API credentials.
