namespace Microsoft.FixedAssets.Depreciation;

using Microsoft.FixedAssets.FixedAsset;
using Microsoft.FixedAssets.Ledger;
using Microsoft.FixedAssets.Maintenance;
using Microsoft.FixedAssets.Posting;

codeunit 5616 "Depreciation Calculation"
{
    Permissions = TableData "FA Ledger Entry" = r,
                  TableData "FA Posting Type Setup" = r,
                  TableData "Maintenance Ledger Entry" = r;

    trigger OnRun()
    begin
    end;

    var
        Text000: Label '%1 %2 = %3 in %4 %5 = %6';
        DeprBookCodeErr: Label ' in depreciation book code %1', Comment = '%1=value for code, e.g. COMAPNY';

    procedure DeprDays(StartingDate: Date; EndingDate: Date; Year365Days: Boolean) NumbefOfDeprDays: Integer
    var
        StartingDay: Integer;
        EndingDay: Integer;
        StartingMonth: Integer;
        EndingMonth: Integer;
        StartingYear: Integer;
        EndingYear: Integer;
    begin
        // Both days are inclusive
        if EndingDate < StartingDate then
            exit(0);
        if (StartingDate = 0D) or (EndingDate = 0D) then
            exit(0);
        if Year365Days then
            exit(DeprDays365(StartingDate, EndingDate));
        StartingDay := Date2DMY(StartingDate, 1);
        EndingDay := Date2DMY(EndingDate, 1);
        StartingMonth := Date2DMY(StartingDate, 2);
        EndingMonth := Date2DMY(EndingDate, 2);
        StartingYear := Date2DMY(StartingDate, 3);
        EndingYear := Date2DMY(EndingDate, 3);
        if Date2DMY(StartingDate, 1) = 31 then
            StartingDay := 30;
        if Date2DMY(EndingDate + 1, 1) = 1 then
            EndingDay := 30;

        NumbefOfDeprDays := 1 + EndingDay - StartingDay + 30 * (EndingMonth - StartingMonth) +
          360 * (EndingYear - StartingYear);

        OnAfterDeprDays(StartingDate, EndingDate, NumbefOfDeprDays, Year365Days);
    end;

    procedure ToMorrow(ThisDate: Date; Year365Days: Boolean): Date
    begin
        if Year365Days then
            exit(ToMorrow365(ThisDate));
        ThisDate := ThisDate + 1;
        if Date2DMY(ThisDate, 1) = 31 then
            ThisDate := ThisDate + 1;
        exit(ThisDate);
    end;

    procedure Yesterday(ThisDate: Date; Year365Days: Boolean): Date
    begin
        if Year365Days then
            exit(Yesterday365(ThisDate));
        if ThisDate = 0D then
            exit(0D);
        if Date2DMY(ThisDate, 1) = 31 then
            ThisDate := ThisDate - 1;
        ThisDate := ThisDate - 1;
        exit(ThisDate);
    end;

    procedure SetFAFilter(var FALedgEntry: Record "FA Ledger Entry"; FANo: Code[20]; DeprBookCode: Code[10]; FAPostingTypeOrder: Boolean)
    begin
        with FALedgEntry do begin
            Reset();
            if FAPostingTypeOrder then begin
                SetCurrentKey(
                  "FA No.", "Depreciation Book Code",
                  "FA Posting Category", "FA Posting Type", "FA Posting Date");
                SetRange("FA Posting Category", "FA Posting Category"::" ");
            end else
                SetCurrentKey("FA No.", "Depreciation Book Code", "FA Posting Date");
            SetRange("FA No.", FANo);
            SetRange("Depreciation Book Code", DeprBookCode);
            SetRange(Reversed, false);
        end;

        OnAfterSetFAFilter(FALedgEntry);
    end;

    procedure CalcEntryAmounts(FANo: Code[20]; DeprBookCode: Code[10]; StartingDate: Date; EndingDate: Date; var EntryAmounts: array[4] of Decimal)
    var
        FALedgEntry: Record "FA Ledger Entry";
        I: Integer;
    begin
        if EndingDate = 0D then
            EndingDate := DMY2Date(31, 12, 9999);
        with FALedgEntry do begin
            SetFAFilter(FALedgEntry, FANo, DeprBookCode, true);
            SetRange("FA Posting Date", StartingDate, EndingDate);
            SetRange("Part of Book Value", true);
            for I := 1 to 4 do begin
                case I of
                    1:
                        SetRange("FA Posting Type", "FA Posting Type"::"Write-Down");
                    2:
                        SetRange("FA Posting Type", "FA Posting Type"::Appreciation);
                    3:
                        SetRange("FA Posting Type", "FA Posting Type"::"Custom 1");
                    4:
                        SetRange("FA Posting Type", "FA Posting Type"::"Custom 2");
                end;
                OnCalcEntryAmountsOnAfterSetFALedgEntryFilters(FALedgEntry, I);
                CalcSums(Amount);
                EntryAmounts[I] := Amount;
            end;
        end;
    end;

    local procedure GetLastEntryDates(FANo: Code[20]; DeprBookCode: Code[10]; var EntryDates: array[4] of Date)
    var
        FALedgEntry: Record "FA Ledger Entry";
        i: Integer;
    begin
        Clear(EntryDates);
        with FALedgEntry do begin
            SetFAFilter(FALedgEntry, FANo, DeprBookCode, true);
            for i := 1 to 4 do begin
                case i of
                    1:
                        SetRange("FA Posting Type", "FA Posting Type"::"Write-Down");
                    2:
                        SetRange("FA Posting Type", "FA Posting Type"::Appreciation);
                    3:
                        SetRange("FA Posting Type", "FA Posting Type"::"Custom 1");
                    4:
                        SetRange("FA Posting Type", "FA Posting Type"::"Custom 2");
                end;
                if GetPartOfCalculation(0, i - 1, DeprBookCode) then
                    if Find('-') then
                        repeat
                            if "Part of Book Value" or "Part of Depreciable Basis" then
                                if "FA Posting Date" > EntryDates[i] then
                                    EntryDates[i] := CheckEntryDate(FALedgEntry, "FA Ledger Entry FA Posting Type".FromInteger(i - 1));
                        until Next() = 0;
            end;
        end;
    end;

    procedure UseDeprStartingDate(FANo: Code[20]; DeprBookCode: Code[10]) Result: Boolean
    var
        FALedgEntry: Record "FA Ledger Entry";
        EntryDates: array[4] of Date;
        i: Integer;
        IsHandled: Boolean;
    begin
        IsHandled := false;
        OnBeforeUseDeprStartingDate(FANo, DeprBookCode, Result, IsHandled);
        if IsHandled then
            exit(Result);

        SetFAFilter(FALedgEntry, FANo, DeprBookCode, true);
        FALedgEntry.SetRange("FA Posting Type", FALedgEntry."FA Posting Type"::Depreciation);
        if FALedgEntry.Find('-') then
            exit(false);

        GetLastEntryDates(FANo, DeprBookCode, EntryDates);
        for i := 1 to 4 do
            if EntryDates[i] > 0D then
                exit(false);
        exit(true);
    end;

    procedure GetFirstDeprDate(FANo: Code[20]; DeprBookCode: Code[10]; Year365Days: Boolean): Date
    var
        FALedgEntry: Record "FA Ledger Entry";
        EntryDates: array[4] of Date;
        LocalDate: Date;
        IsHandled: Boolean;
    begin
        IsHandled := false;
        OnBeforeGetFirstDeprDate(FANo, DeprBookCode, Year365Days, LocalDate, IsHandled);
        if IsHandled then
            exit(LocalDate);

        with FALedgEntry do begin
            SetFAFilter(FALedgEntry, FANo, DeprBookCode, true);
            SetRange("FA Posting Type", "FA Posting Type"::"Acquisition Cost");
            if FindLast() then
                if "FA Posting Date" > LocalDate then
                    LocalDate := "FA Posting Date";
            SetRange("FA Posting Type", "FA Posting Type"::"Salvage Value");
            if FindLast() then
                if "FA Posting Date" > LocalDate then
                    LocalDate := "FA Posting Date";
            SetRange("FA Posting Type", "FA Posting Type"::Depreciation);
            if FindLast() then
                if ToMorrow("FA Posting Date", Year365Days) > LocalDate then
                    LocalDate := ToMorrow("FA Posting Date", Year365Days);
            GetLastEntryDates(FANo, DeprBookCode, EntryDates);
            FindMaxDate(FALedgEntry, EntryDates, LocalDate, Year365Days);
        end;
        exit(LocalDate);
    end;

    local procedure FindMaxDate(var FALedgEntry: Record "FA Ledger Entry"; EntryDates: array[4] of Date; var MaxDate: Date; Year365Days: Boolean)
    var
        i: Integer;
        IsHandled: Boolean;
    begin
        IsHandled := false;
        OnBeforeFindMaxDate(FALedgEntry, EntryDates, Year365Days, MaxDate, IsHandled);
        if IsHandled then
            exit;

        for i := 1 to 4 do
            if EntryDates[i] > MaxDate then
                MaxDate := EntryDates[i];
    end;

    procedure GetMinusBookValue(FANo: Code[20]; DeprBookCode: Code[10]; StartingDate: Date; EndingDate: Date): Decimal
    var
        EntryAmounts: array[4] of Decimal;
        Amount: Decimal;
        i: Integer;
    begin
        CalcEntryAmounts(FANo, DeprBookCode, StartingDate, EndingDate, EntryAmounts);
        for i := 1 to 4 do
            if not GetPartOfCalculation(0, i - 1, DeprBookCode) then
                Amount := Amount + EntryAmounts[i];
        exit(Amount);
    end;

    local procedure CalcMaxDepr(BookValue: Decimal; SalvageValue: Decimal; EndingBookValue: Decimal): Decimal
    var
        MaxDepr: Decimal;
    begin
        if SalvageValue <> 0 then
            EndingBookValue := 0;
        MaxDepr := -(BookValue + SalvageValue - EndingBookValue);
        if MaxDepr > 0 then
            MaxDepr := 0;
        exit(MaxDepr);
    end;

    procedure AdjustDepr(DeprBookCode: Code[10]; var Depreciation: Decimal; BookValue: Decimal; SalvageValue: Decimal; EndingBookValue: Decimal; FinalRoundingAmount: Decimal)
    var
        DeprBook: Record "Depreciation Book";
        MaxDepr: Decimal;
    begin
        if FinalRoundingAmount = 0 then begin
            DeprBook.Get(DeprBookCode);
            FinalRoundingAmount := DeprBook."Default Final Rounding Amount";
        end;
        Depreciation := CalcRounding(DeprBookCode, Depreciation);
        OnAfterCalcDepreciation(DeprBookCode, Depreciation, BookValue);
        if Depreciation >= 0 then
            Depreciation := 0
        else begin
            if SalvageValue <> 0 then
                EndingBookValue := 0;
            MaxDepr := BookValue + SalvageValue - EndingBookValue;
            if MaxDepr + Depreciation < FinalRoundingAmount then
                Depreciation := -MaxDepr;
            if Depreciation > 0 then
                Depreciation := 0;
        end;

        OnAfterAdjustDepr(DeprBookCode, BookValue, MaxDepr, Depreciation);
    end;

    procedure AdjustCustom1(DeprBookCode: Code[10]; var DeprAmount: Decimal; var Custom1Amount: Decimal; BookValue: Decimal; SalvageValue: Decimal; EndingBookValue: Decimal; FinalRoundingAmount: Decimal)
    var
        DeprBook: Record "Depreciation Book";
        MaxDepr: Decimal;
    begin
        if DeprAmount > 0 then
            DeprAmount := 0;
        if Custom1Amount > 0 then
            Custom1Amount := 0;

        DeprAmount := CalcRounding(DeprBookCode, DeprAmount);
        Custom1Amount := CalcRounding(DeprBookCode, Custom1Amount);

        if FinalRoundingAmount = 0 then begin
            DeprBook.Get(DeprBookCode);
            FinalRoundingAmount := DeprBook."Default Final Rounding Amount";
        end;

        if Custom1Amount < 0 then begin
            MaxDepr := CalcMaxDepr(BookValue, SalvageValue, EndingBookValue);
            if Custom1Amount <= MaxDepr then begin
                Custom1Amount := MaxDepr;
                DeprAmount := 0;
            end;
            if DeprAmount >= 0 then
                AdjustDepr(
                  DeprBookCode, Custom1Amount, BookValue, SalvageValue, EndingBookValue, FinalRoundingAmount);
            BookValue := BookValue + Custom1Amount;
        end;
        if DeprAmount < 0 then begin
            MaxDepr := CalcMaxDepr(BookValue, SalvageValue, EndingBookValue);
            if DeprAmount <= MaxDepr then
                DeprAmount := MaxDepr;
            if DeprAmount < 0 then
                AdjustDepr(
                  DeprBookCode, DeprAmount, BookValue, SalvageValue, EndingBookValue, FinalRoundingAmount);
        end;

        if DeprAmount > 0 then
            DeprAmount := 0;
        if Custom1Amount > 0 then
            Custom1Amount := 0;
    end;

    procedure GetSign(BookValue: Decimal; DeprBasis: Decimal; SalvageValue: Decimal; MinusBookValue: Decimal): Integer
    begin
        if (SalvageValue <= 0) and (DeprBasis >= 0) and
           (BookValue >= 0) and (MinusBookValue <= 0)
        then
            exit(1);
        if (SalvageValue >= 0) and (DeprBasis <= 0) and
           (BookValue <= 0) and (MinusBookValue >= 0)
        then
            exit(-1);
        exit(0);
    end;

    procedure GetCustom1Sign(BookValue: Decimal; AcquisitionCost: Decimal; Custom1: Decimal; SalvageValue: Decimal; MinusBookValue: Decimal): Integer
    begin
        if (SalvageValue <= 0) and (AcquisitionCost >= 0) and
           (BookValue >= 0) and (Custom1 <= 0) and (MinusBookValue <= 0)
        then
            exit(1);
        if (SalvageValue >= 0) and (AcquisitionCost <= 0) and
           (BookValue <= 0) and (Custom1 >= 0) and (MinusBookValue >= 0)
        then
            exit(-1);
        exit(0);
    end;

    procedure GetNewSigns(var BookValue: Decimal; var DeprBasis: Decimal; var SalvageValue: Decimal; var MinusBookValue: Decimal)
    begin
        BookValue := -BookValue;
        DeprBasis := -DeprBasis;
        SalvageValue := -SalvageValue;
        MinusBookValue := -MinusBookValue;
    end;

    procedure GetNewCustom1Signs(var BookValue: Decimal; var AcquisitionCost: Decimal; var Custom1: Decimal; var SalvageValue: Decimal; var MinusBookValue: Decimal)
    begin
        BookValue := -BookValue;
        AcquisitionCost := -AcquisitionCost;
        Custom1 := -Custom1;
        SalvageValue := -SalvageValue;
        MinusBookValue := -MinusBookValue;
    end;

    procedure CalcRounding(DeprBookCode: Code[10]; DeprAmount: Decimal): Decimal
    var
        DeprBook: Record "Depreciation Book";
        IsHandled: Boolean;
    begin
        with DeprBook do begin
            Get(DeprBookCode);

            IsHandled := false;
            OnBeforeCalcRounding(DeprBook, DeprAmount, IsHandled);
            if IsHandled then
                exit(DeprAmount);

            if "Use Rounding in Periodic Depr." then
                exit(Round(DeprAmount, 1));

            exit(Round(DeprAmount));
        end;
    end;

    procedure CalculateDeprInPeriod(FANo: Code[20]; DeprBookCode: Code[10]; EndingDate: Date; CalculatedDepr: Decimal; Sign: Integer; var NewBookValue: Decimal; var DeprBasis: Decimal; var SalvageValue: Decimal; var MinusBookValue: Decimal)
    var
        FALedgEntry: Record "FA Ledger Entry";
    begin
        with FALedgEntry do begin
            SetCurrentKey("FA No.", "Depreciation Book Code", "Part of Book Value", "FA Posting Date");
            SetRange("Depreciation Book Code", DeprBookCode);
            SetRange("FA No.", FANo);
            SetRange("FA Posting Date", 0D, EndingDate);
            SetRange("Part of Book Value", true);
            CalcSums(Amount);
            NewBookValue := Sign * Amount + CalculatedDepr;
            SetRange("Part of Book Value");
            SetCurrentKey("FA No.", "Depreciation Book Code", "Part of Depreciable Basis", "FA Posting Date");
            SetRange("Part of Depreciable Basis", true);
            CalcSums(Amount);
            DeprBasis := Sign * Amount;
            SetRange("Part of Depreciable Basis");
            SetCurrentKey(
              "FA No.", "Depreciation Book Code",
              "FA Posting Category", "FA Posting Type", "FA Posting Date");
            SetRange("FA Posting Category", "FA Posting Category"::" ");
            SetRange("FA Posting Type", "FA Posting Type"::"Salvage Value");
            CalcSums(Amount);
            SalvageValue := Sign * Amount;
            MinusBookValue := Sign * GetMinusBookValue(FANo, DeprBookCode, 0D, EndingDate);
        end;
    end;

    procedure GetDeprPeriod(FANo: Code[20]; DeprBookCode: Code[10]; UntilDate: Date; var StartingDate: Date; var EndingDate: Date; var NumberOfDays: Integer; Year365Days: Boolean)
    var
        FALedgEntry: Record "FA Ledger Entry";
        FADeprBook: Record "FA Depreciation Book";
        UsedDeprStartingDate: Boolean;
    begin
        FADeprBook.Get(FANo, DeprBookCode);
        with FALedgEntry do begin
            // Calculate Starting Date
            if StartingDate = 0D then begin
                SetFAFilter(FALedgEntry, FANo, DeprBookCode, true);
                SetRange("FA Posting Type", "FA Posting Type"::Depreciation);
                if Find('+') then
                    StartingDate := ToMorrow("FA Posting Date", Year365Days)
                else begin
                    StartingDate := FADeprBook."Depreciation Starting Date";
                    UsedDeprStartingDate := true;
                end;
            end else
                StartingDate := ToMorrow(EndingDate, Year365Days);

            // Calculate Ending Date
            EndingDate := 0D;
            SetFAFilter(FALedgEntry, FANo, DeprBookCode, false);
            if not UsedDeprStartingDate then
                SetFilter("FA Posting Date", '%1..', StartingDate + 1);
            if Find('-') then
                repeat
                    if "Part of Book Value" or "Part of Depreciable Basis" then begin
                        if ("FA Posting Type" = "FA Posting Type"::"Acquisition Cost") or
                           ("FA Posting Type" = "FA Posting Type"::"Salvage Value")
                        then begin
                            if not UsedDeprStartingDate then
                                EndingDate := "FA Posting Date";
                        end else
                            if GetPartOfDeprCalculation(FALedgEntry) then
                                EndingDate := "FA Posting Date";
                        EndingDate := Yesterday(EndingDate, Year365Days);
                        if EndingDate < StartingDate then
                            EndingDate := 0D;
                    end;
                until (Next() = 0) or (EndingDate > 0D);
        end;
        if EndingDate = 0D then
            EndingDate := UntilDate;
        NumberOfDays := DeprDays(StartingDate, EndingDate, Year365Days);

        OnAfterGetDeprPeriod(FANo, DeprBookCode, UntilDate, StartingDate, EndingDate, NumberOfDays, Year365Days);
    end;

    procedure DeprInFiscalYear(FANo: Code[20]; DeprBookCode: Code[10]; StartingDate: Date): Decimal
    var
        FALedgEntry: Record "FA Ledger Entry";
        FADateCalc: Codeunit "FA Date Calculation";
        LocalAmount: Decimal;
        EntryAmounts: array[4] of Decimal;
        FiscalYearBegin: Date;
        i: Integer;
    begin
        FiscalYearBegin := FADateCalc.GetFiscalYear(DeprBookCode, StartingDate);
        with FALedgEntry do begin
            SetFAFilter(FALedgEntry, FANo, DeprBookCode, true);
            SetFilter("FA Posting Date", '%1..', FiscalYearBegin);
            SetRange("FA Posting Type", "FA Posting Type"::Depreciation);
            SetRange("Part of Book Value", true);
            SetRange("Reclassification Entry", false);
            CalcSums(Amount);
            LocalAmount := Amount;
            CalcEntryAmounts(FANo, DeprBookCode, FiscalYearBegin, 0D, EntryAmounts);
            for i := 1 to 4 do
                if GetPartOfCalculation(2, i - 1, DeprBookCode) then
                    LocalAmount := LocalAmount + EntryAmounts[i];
        end;
        exit(LocalAmount);
    end;

    procedure GetPartOfCalculation(Type: Option IncludeInDeprCalc,IncludeInGainLoss,DepreciationType,ReverseType; PostingType: Option "Write-Down",Appreciation,"Custom 1","Custom 2"; DeprBookCode: Code[10]): Boolean
    var
        FAPostingTypeSetup: Record "FA Posting Type Setup";
    begin
        with FAPostingTypeSetup do begin
            case PostingType of
                PostingType::"Write-Down":
                    Get(DeprBookCode, "FA Posting Type"::"Write-Down");
                PostingType::Appreciation:
                    Get(DeprBookCode, "FA Posting Type"::Appreciation);
                PostingType::"Custom 1":
                    Get(DeprBookCode, "FA Posting Type"::"Custom 1");
                PostingType::"Custom 2":
                    Get(DeprBookCode, "FA Posting Type"::"Custom 2");
            end;
            OnAfterGetFAPostingTypeSetup(FAPostingTypeSetup, Type);

            if Type = Type::IncludeInDeprCalc then
                exit("Include in Depr. Calculation");
            if Type = Type::IncludeInGainLoss then
                exit("Include in Gain/Loss Calc.");
            if Type = Type::DepreciationType then
                exit("Depreciation Type");
            if Type = Type::ReverseType then
                exit("Reverse before Disposal");
        end;
    end;

    local procedure GetPartOfDeprCalculation(var FALedgEntry: Record "FA Ledger Entry"): Boolean
    var
        i: Integer;
    begin
        with FALedgEntry do begin
            case "FA Posting Type" of
                "FA Posting Type"::"Write-Down":
                    i := 1;
                "FA Posting Type"::Appreciation:
                    i := 2;
                "FA Posting Type"::"Custom 1":
                    i := 3;
                "FA Posting Type"::"Custom 2":
                    i := 4;
            end;
            if i = 0 then
                exit(false);

            exit(GetPartOfCalculation(0, i - 1, "Depreciation Book Code"));
        end;
    end;

    procedure FAName(var FA: Record "Fixed Asset"; DeprBookCode: Code[10]): Text[200]
    var
        DeprBook: Record "Depreciation Book";
    begin
        if DeprBookCode = '' then
            exit(StrSubstNo('%1 %2 = %3', FA.TableCaption(), FA.FieldCaption("No."), FA."No."));

        exit(
          StrSubstNo(
            Text000,
            FA.TableCaption(), FA.FieldCaption("No."), FA."No.",
            DeprBook.TableCaption(), DeprBook.FieldCaption(Code), DeprBookCode));
    end;

    procedure FADeprBookName(DeprBookCode: Code[10]): Text[200]
    begin
        if DeprBookCode = '' then
            exit('');

        exit(StrSubstNo(DeprBookCodeErr, DeprBookCode));
    end;

    procedure DeprDays365(StartingDate: Date; EndingDate: Date): Integer
    var
        StartingYear: Integer;
        EndingYear: Integer;
        ActualYear: Integer;
        LeapDate: Date;
        LeapDays: Integer;
    begin
        StartingYear := Date2DMY(StartingDate, 3);
        EndingYear := Date2DMY(EndingDate, 3);
        LeapDays := 0;
        if (Date2DMY(StartingDate, 1) = 29) and (Date2DMY(StartingDate, 2) = 2) and
           (Date2DMY(EndingDate, 1) = 29) and (Date2DMY(EndingDate, 2) = 2)
        then
            LeapDays := -1;

        ActualYear := StartingYear;
        while ActualYear <= EndingYear do begin
            LeapDate := (DMY2Date(28, 2, ActualYear) + 1);
            if Date2DMY(LeapDate, 1) = 29 then
                if (LeapDate >= StartingDate) and (LeapDate <= EndingDate) then
                    LeapDays := LeapDays + 1;
            ActualYear := ActualYear + 1;
        end;
        exit((EndingDate - StartingDate) + 1 - LeapDays);
    end;

    local procedure ToMorrow365(ThisDate: Date): Date
    begin
        ThisDate := ThisDate + 1;
        if (Date2DMY(ThisDate, 1) = 29) and (Date2DMY(ThisDate, 2) = 2) then
            ThisDate := ThisDate + 1;
        exit(ThisDate);
    end;

    local procedure Yesterday365(ThisDate: Date): Date
    begin
        if ThisDate = 0D then
            exit(0D);
        if (Date2DMY(ThisDate, 1) = 29) and (Date2DMY(ThisDate, 2) = 2) then
            ThisDate := ThisDate - 1;
        ThisDate := ThisDate - 1;
        exit(ThisDate);
    end;

    local procedure CheckEntryDate(FALedgerEntry: Record "FA Ledger Entry"; FAPostingType: Enum "FA Ledger Entry FA Posting Type"): Date
    begin
        with FALedgerEntry do begin
            if IsDepreciationTypeEntry("Depreciation Book Code", FAPostingType) then
                exit("FA Posting Date" + 1);
            exit("FA Posting Date");
        end;
    end;

    local procedure IsDepreciationTypeEntry(DeprBookCode: Code[10]; FAPostingType: Enum "FA Ledger Entry FA Posting Type"): Boolean
    var
        FAPostingTypeSetup: Record "FA Posting Type Setup";
    begin
        FAPostingTypeSetup.Get(DeprBookCode, FAPostingType);
        exit(FAPostingTypeSetup."Depreciation Type");
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterAdjustDepr(DeprBookCode: Code[10]; BookValue: Decimal; MaxValue: Decimal; var Depreciation: Decimal)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterCalcDepreciation(DeprBookCode: Code[10]; var Depreciation: Decimal; BookValue: Decimal)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterDeprDays(StartingDate: Date; EndingDate: Date; var NumberOfDeprDays: Integer; Year365Days: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterGetDeprPeriod(FANo: Code[20]; DeprBookCode: Code[10]; UntilDate: Date; var StartingDate: Date; var EndingDate: Date; var NumberOfDays: Integer; Year365Days: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeCalcRounding(DeprBook: Record "Depreciation Book"; var DeprAmount: Decimal; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeFindMaxDate(var FALedgEntry: Record "FA Ledger Entry"; EntryDates: array[4] of Date; Year365Days: Boolean; var MaxDate: Date; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeGetFirstDeprDate(FixedAssetNo: Code[20]; DepreciationBookCode: Code[10]; Year365Days: Boolean; var LocalDate: Date; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeUseDeprStartingDate(FANo: Code[20]; DeprBookCode: Code[10]; var Result: Boolean; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterGetFAPostingTypeSetup(var FAPostingTypeSetup: Record "FA Posting Type Setup"; Type: Option IncludeInDeprCalc,IncludeInGainLoss,DepreciationType,ReverseType)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnCalcEntryAmountsOnAfterSetFALedgEntryFilters(var FALedgerEntry: Record "FA Ledger Entry"; I: Integer)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterSetFAFilter(var FALedgerEntry: Record "FA Ledger Entry")
    begin
    end;
}

