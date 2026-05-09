Option Explicit

Dim shell, fso, vbsDir, scriptPath, result

Set shell  = CreateObject("WScript.Shell")
Set fso    = CreateObject("Scripting.FileSystemObject")

vbsDir     = fso.GetParentFolderName(WScript.ScriptFullName)
scriptPath = vbsDir & "\stock.py"

If Not fso.FileExists(scriptPath) Then
    MsgBox "[오류] stock.py 파일을 찾을 수 없습니다." & vbNewLine & vbNewLine _
         & "이 파일과 stock.py 를 같은 폴더에 두세요." & vbNewLine & vbNewLine _
         & "현재 폴더: " & vbsDir, vbCritical, "ETF 시세 업데이트"
    WScript.Quit 1
End If

result = shell.Run("python """ & scriptPath & """", 0, True)

If result = 0 Then
    MsgBox "[완료] 시세 업데이트가 완료되었습니다!" & vbNewLine & vbNewLine _
         & "브라우저에서 F5 를 눌러 새로고침하면" & vbNewLine _
         & "최신 시세가 바로 반영됩니다.", _
         vbInformation, "ETF 시세 업데이트"
Else
    MsgBox "[오류] 업데이트 중 오류가 발생했습니다. (코드: " & result & ")" & vbNewLine & vbNewLine _
         & "확인사항:" & vbNewLine _
         & "  1. Python 이 설치되어 있는지 확인" & vbNewLine _
         & "  2. FinanceDataReader 패키지 설치 여부 확인" & vbNewLine _
         & "     (pip install finance-datareader)", _
         vbCritical, "ETF 시세 업데이트"
End If

Set shell = Nothing
Set fso   = Nothing
