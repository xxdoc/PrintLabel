Attribute VB_Name = "SampleSource"
Option Explicit
Public Const SHT_SAMPLE As String = "src_sampleV1.3.3"
Private Const SYMBOL_END As String = "end"
Private Const SYMBOL_OK As String = "ok"
Private Const COl_DEPART As Long = 6 '两个工作簿源相隔列数
Private Const COL_SCANNED As Long = 4 '扫描列队工作簿所在列的距离
Private Const ROW_SCANNED As Long = 7 '扫描记录开始行

Sub Sample_Init()
    Call InitANewSht(gBk, SHT_SAMPLE, False)
End Sub

'函数名称：Sample_ImportData
'功能描述：导入样本
'参数说明：Paths需要导入的文件数组
'返回值：true导入成功
Public Function Sample_ImportData(Paths) As Boolean
    If Not IsArray(Paths) Then
        Sample_ImportData = False '没有选择任何工作簿，则提示导入失败
        Exit Function
    End If
    Sample_ImportData = True
    Call Sample_Init
    Dim wkBk As Workbook
    Dim i As Long, strPath As String, symbol As String, str As String
    Dim ShtSrc As Worksheet, ShtDst As Worksheet
    Dim Rng As Range
    Dim nCol As Long, nRow As Long, CurCol As Long, curRow As Long, LstRow As Long
    symbol = "正面条码"
    Set ShtDst = gBk.Worksheets(SHT_SAMPLE)
    CurCol = 1
    For i = LBound(Paths) To UBound(Paths)
        strPath = Paths(i)
        If Dir(strPath) <> "" Then
            Set wkBk = ExcelApp.Workbooks.Open(strPath)
            For Each ShtSrc In wkBk.Worksheets
                Set Rng = ShtSrc.Rows(4).Find(what:=symbol, lookat:=xlWhole)
                If Not Rng Is Nothing Then
                    curRow = 1
                    ShtDst.Cells(VPP(curRow), CurCol) = wkBk.Name
                    ShtDst.Cells(curRow, CurCol) = "订单编号："
                    ShtDst.Cells(VPP(curRow), CurCol + 1) = ShtSrc.Cells(2, "B")
                    
                    ShtDst.Cells(curRow, CurCol) = "经销店面："
                    ShtDst.Cells(VPP(curRow), CurCol + 1) = ShtSrc.Cells(3, "B")
                    
                    ShtDst.Cells(curRow, CurCol) = "产品类别："
                    str = ShtSrc.Cells(3, "K")
                    ShtDst.Cells(VPP(curRow), CurCol + 1) = Trim(IIf(Len(str) > 5, Right(str, Len(str) - 5), str))
                    
                    str = ShtSrc.Cells(3, "C")
                    ShtDst.Cells(curRow, CurCol + 0) = "终端客户"
                    ShtDst.Cells(VPP(curRow), CurCol + 1) = Trim(IIf(Len(str) > 5, Right(str, Len(str) - 5), str))
                    
                    ShtDst.Cells(curRow, CurCol + 0) = "正面条码"
                    ShtDst.Cells(curRow, CurCol + 1) = "样板名称"
                    ShtDst.Cells(curRow, CurCol + 2) = "是否扫描"
                    ShtDst.Cells(curRow, CurCol + 3) = "第几包"
                    ShtDst.Cells(curRow, CurCol + COL_SCANNED) = "扫描顺序"
                    ShtDst.Cells(curRow + 1, CurCol + COL_SCANNED) = SYMBOL_END
                    Call VPP(curRow)
                    
                    nCol = Rng.Column
                    
                    LstRow = ShtSrc.Cells(ShtSrc.Rows.count, nCol).End(xlUp).Row
                    For nRow = Rng.Row + 1 To LstRow
                        str = ShtSrc.Cells(nRow, 1)
                        If InStr(str, "小计") > 0 And ShtSrc.Cells(nRow, 1).MergeCells Then
                            '如果遇到小计，就退出
                            Exit For
                        End If
                        ShtDst.Cells(curRow, CurCol) = ShtSrc.Cells(nRow, nCol)
                        ShtDst.Cells(curRow, CurCol + 1) = ShtSrc.Cells(nRow, 1)
                        Call VPP(curRow)
                    Next
                    ShtDst.Columns(CurCol).ColumnWidth = COL_WIDTH_CODE
                    ShtDst.Columns(CurCol + 1).AutoFit
                    CurCol = CurCol + COl_DEPART
                End If
                Set Rng = Nothing
            Next
            wkBk.Close False
            Set ShtSrc = Nothing
            Set wkBk = Nothing
        End If
    Next
    'ShtDst.Columns.AutoFit
    Set ShtDst = Nothing
    Call gShtScan.SetValidation(Paths)
End Function

'功能描述：获取正在处理的工作簿已经扫描结果
'参数说明：无
'返回值：为空则没有结果，不为空但是不是数组则只有一条结果，是数组则有多条结果，二维数组
Public Function Sample_GetScannedCode()
    Dim wkSht As Worksheet
    Dim CurCol As Long, LstRow As Long, curRow As Long
    Dim arrRet
    Set wkSht = gBk.Worksheets(SHT_SAMPLE)
    CurCol = GetCurHandleCol(wkSht)
    LstRow = wkSht.Cells(wkSht.Rows.count, CurCol + COL_SCANNED).End(xlUp).Row
    curRow = ROW_SCANNED + 1
    If LstRow > ROW_SCANNED Then
        arrRet = wkSht.Cells(curRow, CurCol + COL_SCANNED).Resize(LstRow - curRow + 1, 2)
    End If
    Set wkSht = Nothing
    Sample_GetScannedCode = arrRet
End Function

'功能描述：添加扫描结果
'参数说明：
'       str 需要添加的条码
'返回值：true当前条码添加成功，false添加失败
Public Function Sample_AddScanResult(ByVal str As String) As Boolean
    Dim bRet As Boolean
    Dim wkSht As Worksheet
    Dim LstRow As Long
    Dim CurCol As Long, ScanCol As Long
    Set wkSht = gBk.Worksheets(SHT_SAMPLE)
    CurCol = GetCurHandleCol(wkSht)
    If CurCol = 0 Then
        ShowMsg "先选择一个需要处理的工作簿名称"
        bRet = False
        GoTo LineEnd '不存在当前处理，扫描结果里面没有填当前处理的工作簿
    End If
    ScanCol = CurCol + COL_SCANNED
    If VBA.LCase(str) <> SYMBOL_END Then
        '检测样本中是否包含需要扫描的条码
        If Not ScanCodeIsExist(wkSht, str, CurCol) Then
            ShowMsg "当前处理工作簿，不包含扫描条码，请重新扫描其他条码"
            bRet = False
            GoTo LineEnd
        End If
        '检测是否已经扫描过了
        If ScanCodeIsExist(wkSht, str, ScanCol) Then
            ShowMsg "已经扫描过当前条码，请扫描其他的条码"
            bRet = False
            GoTo LineEnd
        End If
    End If
    
    LstRow = wkSht.Cells(wkSht.Rows.count, ScanCol).End(xlUp).Row
    If VBA.LCase(wkSht.Cells(LstRow, ScanCol)) = VBA.LCase(str) Then
        bRet = True
        GoTo LineEnd
    End If
    Call VPP(LstRow)
    wkSht.Cells(LstRow, ScanCol) = str
    wkSht.Columns(ScanCol).AutoFit
    
    Dim bPrint As Boolean, bFinished As Boolean
    bPrint = False: bFinished = False
    If VBA.LCase(str) = SYMBOL_END Then
        '如果是出现了end，则打印标签
        bPrint = True
        '出现end不打印标签，等待整个文件扫描完成后再打印
    Else
        '如果不是end，需要检测是否扫描完
        If CheckFinished(wkSht, str, CurCol) Then
            bFinished = True
            bPrint = True
            Call VPP(LstRow) '如果是扫描完成，则需要下移一行
            Dim msg As String
            msg = "已经扫描完一个工作簿" & Chr(10) & _
                "工作簿：" & wkSht.Cells(1, CurCol) & Chr(10)
            Call ShowMsg(msg)
        End If
    End If
    If bPrint Then
        '如果扫描到End则打印一个
        Call PrintEndLabel
    End If
        
        
    
    If bFinished Then
        '如果扫描完成后，则打印全部的标签
        Call PrintAllLabel
        gShtScan.InitScanInfo
    End If
    bRet = True
LineEnd:
    Sample_AddScanResult = bRet
    Set wkSht = Nothing
End Function

'功能描述：获取当前处理工作簿基本信息
'参数说明：无
'返回值：基本信息数组
Public Function Sample_GetInfo()
    Dim wkSht As Worksheet
    Dim CurCol As Long, LstRow As Long
    Dim arr
    Set wkSht = gBk.Worksheets(SHT_SAMPLE)
    CurCol = GetCurHandleCol(wkSht)
    LstRow = Sht_GetLstRow(wkSht, CurCol, CurCol + COL_SCANNED)
    arr = wkSht.Range(wkSht.Cells(2, CurCol), wkSht.Cells(LstRow, CurCol + 4))
    Sample_GetInfo = arr
    Set wkSht = Nothing
End Function

'功能描述：设置当前条码的状态，并判断整个工作簿是否扫描完成
'参数说明：
'   wkSht   需要处理的工作表
'   str     需要处理的条码
'   nCol    条码所在的列号
'返回值：true扫描完成，false没有完成
Private Function CheckFinished(wkSht As Worksheet, str As String, ByVal nCol As Long) As Boolean
    Dim Rng As Range
    Dim CurCol As Long, LstRow As Long
    CheckFinished = False
    Set Rng = wkSht.Columns(nCol).Find(what:=str, lookat:=xlWhole)
    If Not Rng Is Nothing Then
        Rng.Offset(0, 2) = True
        LstRow = wkSht.Cells(wkSht.Rows.count, Rng.Column).End(xlUp).Row
        Dim arr
        arr = wkSht.Range(wkSht.Cells(ROW_SCANNED, nCol + 2), wkSht.Cells(LstRow, nCol + 2))
        If IsArray(arr) Then
            If ArrIsAllValue(arr, True) Then
                CheckFinished = True
            End If
        Else
            CheckFinished = arr = True
        End If
        Set Rng = Nothing
    End If
    wkSht.Cells(2, nCol + 2) = IIf(CheckFinished, "扫描完成", "")
End Function

'功能描述：获取需要打印的条码
'参数说明：
'   wkSht   需要处理的工作表
'   nCol    条码所在的列号
'返回值：一个二维数组，如果没有需要显示的，则为空，不是数组
Private Function GetDisCode(wkSht As Worksheet, nCol As Long)
    Dim nRow As Long, LstRow As Long
    Dim str As String
    Dim Rng As Range
    Dim arr
    LstRow = Sht_GetLstRow(wkSht, nCol)
    arr = wkSht.Range(wkSht.Cells(ROW_SCANNED + 1, nCol), wkSht.Cells(LstRow, nCol + 1))
    For nRow = LBound(arr, 1) To UBound(arr, 1)
        str = arr(nRow, 1)
        If VBA.LCase(str) <> SYMBOL_END Then
            Set Rng = wkSht.Columns(nCol - COL_SCANNED).Find(what:=str, lookat:=xlWhole)
            If Rng Is Nothing Then
                arr(nRow, 2) = ""
            Else
                arr(nRow, 2) = Rng.Offset(0, 1)
            End If
        End If
    Next
    GetDisCode = arr
End Function

'功能描述：获取需要打印的标签
'参数说明：
'   arr     条码数组
'   wkSht   处理的工作表
'   nCol    条码所在的列号
'返回值：一维数组
Private Function GetDisLabel(arr, wkSht As Worksheet, nCol As Long)
    Dim arrRet, str As String
    Dim i As Long
    Dim Rng As Range
    ReDim arrRet(LBound(arr, 1) To UBound(arr, 1))
    For i = LBound(arr, 1) To UBound(arr, 1)
        str = arr(i, LBound(arr, 2))
        Set Rng = wkSht.Columns(nCol).Find(what:=str, lookat:=xlWhole)
        If Not Rng Is Nothing Then
            arrRet(i) = Rng.Offset(0, 1)
            Set Rng = Nothing
        End If
    Next
    GetDisLabel = arrRet
End Function

'功能描述：返回当前的扫描个数
'参数说明：
'   wkSht   所在工作表
'   nCol    条码所在的列号
'返回值：有效条码个数
Private Function GetLableCount(wkSht As Worksheet, nCol As Long) As Long
    Dim LstRow As Long, nRow As Long
    Dim count As Long
    count = 0
    LstRow = wkSht.Cells(wkSht.Rows.count, nCol).End(xlUp).Row
    For nRow = ROW_SCANNED To LstRow
        If wkSht.Cells(nRow, nCol) <> SYMBOL_END Then
            VPP count
        End If
    Next
    GetLableCount = count
End Function

'功能描述：判断指定列中条码是否存在
'参数说明：
'   wkSht   处理的工作表
'   strCode 条码
'   nCol    判断的列号
'返回值：true指定列存在指定的条码
Private Function ScanCodeIsExist(wkSht As Worksheet, strCode As String, nCol As Long) As Boolean
    Dim Rng As Range
    Dim bRet As Boolean
    Set Rng = wkSht.Columns(nCol).Find(what:=strCode, lookat:=xlWhole)
    If Not Rng Is Nothing Then
        bRet = True
    Else
        bRet = False
    End If
    Set Rng = Nothing
    ScanCodeIsExist = bRet
End Function

'功能描述：获取当前正在处理的工作簿扫描结果所在的列号
'参数说明：
'   wkSht   处理的工作表
'返回值：当前正在扫描的工作簿的结果所在的起始列号
Private Function GetCurHandleCol(wkSht As Worksheet)
    Dim CurHandle As String
    Dim Rng As Range
    CurHandle = gShtScan.GetCurHandle
    If CurHandle = "" Then
        GetCurHandleCol = 0
        Exit Function
    End If
    Set Rng = wkSht.Rows(1).Find(what:=CurHandle, lookat:=xlWhole)
    If Not Rng Is Nothing Then
        GetCurHandleCol = Rng.Column
        Set Rng = Nothing
    Else
        GetCurHandleCol = 0
    End If
End Function
'打印扫描文件的所有标签
Private Sub PrintAllLabel()
    Dim ArrLabel
    Dim arrCode
    Dim arrName
    Dim str As String, orderSn As String
    Dim index As Long, count As Long, ScanCol As Long, CurCol As Long
    Dim nRow As Long
    Dim wkSht As Worksheet
    Dim Rng As Range
    Dim nCount As Long
    
    Set wkSht = gBk.Worksheets(SHT_SAMPLE)
    CurCol = GetCurHandleCol(wkSht)
    ScanCol = CurCol + COL_SCANNED
    orderSn = wkSht.Cells(2, CurCol + 1)
    '获取全部的扫描的条码
    ArrLabel = GetDisCode(wkSht, ScanCol)
    
    '统计有几包
    For nRow = LBound(ArrLabel, 1) To UBound(ArrLabel, 1)
        str = ArrLabel(nRow, LBound(ArrLabel, 2))
        If VBA.LCase(str) = SYMBOL_END Then
            VPP count
        Else
            VPP nCount
        End If
        If nRow = UBound(ArrLabel, 1) And VBA.LCase(str) <> SYMBOL_END Then
            VPP count '最后一次情况
        End If
    Next
    index = 1
    ReDim arrCode(0) As String
    ReDim arrName(0) As String
    For nRow = LBound(ArrLabel, 1) To UBound(ArrLabel, 1)
        str = ArrLabel(nRow, LBound(ArrLabel, 2))
        If VBA.LCase(str) = SYMBOL_END Then
            '如果遇到end，则打印之前的条码
            Call Label_Print(arrName, orderSn, wkSht.Cells(4, CurCol + 1), wkSht.Cells(5, CurCol + 1), index, count)
            ReDim arrCode(0) As String
            ReDim arrName(0) As String
            VPP index
        Else
            '否则添加
            arrCode(UBound(arrCode)) = str
            wkSht.Cells(ROW_SCANNED + nRow, ScanCol + 1) = "第" & index & "包"
            Set Rng = wkSht.Columns.Find(what:=str, lookat:=xlWhole)
            If Not Rng Is Nothing Then
                Rng.Offset(0, 3) = "第" & index & "包"
                Set Rng = Nothing
            End If
            arrName(UBound(arrName)) = ArrLabel(nRow, LBound(ArrLabel, 2) + 1)
            ReDim Preserve arrCode(LBound(arrCode) To UBound(arrCode) + 1) As String
            ReDim Preserve arrName(LBound(arrName) To UBound(arrName) + 1) As String
        End If
    Next
    str = ArrLabel(UBound(ArrLabel, 1), LBound(ArrLabel, 2))
    If VBA.LCase(str) <> SYMBOL_END Then
        '如果遇到end，则打印之前的条码
        Call Label_Print(arrName, orderSn, wkSht.Cells(4, CurCol + 1), wkSht.Cells(5, CurCol + 1), index, count)
        ReDim arrCode(0) As String
        ReDim arrName(0) As String
    End If
    Call Label_PrintFinal(orderSn, wkSht.Cells(4, CurCol + 1), wkSht.Cells(5, CurCol + 1), count, nCount)
End Sub
Private Sub PrintEndLabel()
    Dim ArrLabel
    Dim arrCode
    Dim arrName
    Dim str As String, orderSn As String
    Dim index As Long, count As Long, ScanCol As Long, CurCol As Long
    Dim nRow As Long, i As Long, endRow As Long
    Dim wkSht As Worksheet
    Dim Rng As Range
    Dim nCount As Long
    
    Set wkSht = gBk.Worksheets(SHT_SAMPLE)
    CurCol = GetCurHandleCol(wkSht)
    ScanCol = CurCol + COL_SCANNED
    orderSn = wkSht.Cells(2, CurCol + 1)
    '获取全部的扫描的条码
    ArrLabel = GetDisCode(wkSht, ScanCol)
    
    '统计有几包
    For nRow = LBound(ArrLabel, 1) To UBound(ArrLabel, 1)
        str = ArrLabel(nRow, LBound(ArrLabel, 2))
        If VBA.LCase(str) = SYMBOL_END Then
            VPP count
        Else
            VPP nCount
        End If
        If nRow = UBound(ArrLabel, 1) And VBA.LCase(str) <> SYMBOL_END Then
            VPP count '最后一次情况
        End If
    Next
    
    For i = UBound(ArrLabel, 1) - 1 To LBound(ArrLabel, 1) Step -1
        str = ArrLabel(i, LBound(ArrLabel, 2))
        If VBA.LCase(str) = SYMBOL_END Then
            Exit For
        End If
    Next

    index = count
    count = 0
    ReDim arrCode(0) As String
    ReDim arrName(0) As String
    str = ArrLabel(UBound(ArrLabel, 1), LBound(ArrLabel, 1))
    If VBA.LCase(str) = SYMBOL_END Then
        endRow = UBound(ArrLabel, 1) - 1
    Else
        endRow = UBound(ArrLabel, 1)
    End If
    For nRow = i + 1 To endRow '最后一个是end，不需要打印
        arrCode(UBound(arrCode)) = str
        arrName(UBound(arrName)) = ArrLabel(nRow, LBound(ArrLabel, 2) + 1)
        ReDim Preserve arrCode(LBound(arrCode) To UBound(arrCode) + 1) As String
        ReDim Preserve arrName(LBound(arrName) To UBound(arrName) + 1) As String
    Next
    Call Label_Print(arrName, orderSn, wkSht.Cells(4, CurCol + 1), wkSht.Cells(5, CurCol + 1), index, count)
    
End Sub

