﻿#if not CLEAN22
// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.Inventory.Intrastat;

using Microsoft.Finance.Currency;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Finance.VAT.Setup;
using Microsoft.Foundation.Address;
using Microsoft.Foundation.Company;
using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Ledger;
using Microsoft.Purchases.History;
using Microsoft.Sales.Customer;
using Microsoft.Sales.History;
using Microsoft.Service.History;

report 594 "Get Item Ledger Entries"
{
    Caption = 'Get Item Ledger Entries';
    Permissions = TableData "General Posting Setup" = rimd;
    ProcessingOnly = true;
    ObsoleteState = Pending;
    ObsoleteTag = '22.0';
    ObsoleteReason = 'Intrastat related functionalities are moved to Intrastat extensions.';

    dataset
    {
        dataitem("Country/Region"; "Country/Region")
        {
            DataItemTableView = sorting("Intrastat Code") where("Intrastat Code" = filter(<> ''));
            dataitem("Item Ledger Entry"; "Item Ledger Entry")
            {
                DataItemTableView = sorting("Country/Region Code", "Entry Type", "Posting Date") where("Entry Type" = filter(Purchase | Sale | Transfer), Correction = const(false));

                trigger OnAfterGetRecord()
                var
                    ItemLedgEntry: Record "Item Ledger Entry";
                begin
                    IntrastatJnlLine2.SetRange("Source Entry No.", "Entry No.");
                    if IntrastatJnlLine2.FindFirst() then
                        CurrReport.Skip();

                    if "Entry Type" in ["Entry Type"::Sale, "Entry Type"::Purchase] then begin
                        ItemLedgEntry.Reset();
                        ItemLedgEntry.SetCurrentKey("Document No.", "Document Type");
                        ItemLedgEntry.SetRange("Document No.", "Document No.");
                        ItemLedgEntry.SetRange("Item No.", "Item No.");
                        ItemLedgEntry.SetRange(Correction, true);
                        if "Document Type" in ["Document Type"::"Sales Shipment", "Document Type"::"Sales Return Receipt",
                                               "Document Type"::"Purchase Receipt", "Document Type"::"Purchase Return Shipment"]
                        then begin
                            ItemLedgEntry.SetRange("Document Type", "Document Type");
                            if ItemLedgEntry.FindSet() then
                                repeat
                                    if IsItemLedgerEntryCorrected(ItemLedgEntry, "Entry No.") then
                                        CurrReport.Skip();
                                until ItemLedgEntry.Next() = 0;
                        end;
                    end;

                    if not HasCrossedBorder("Item Ledger Entry") or IsService("Item Ledger Entry") or IsServiceItem("Item No.") then
                        CurrReport.Skip();

                    CalculateTotals("Item Ledger Entry");

                    if (TotalAmt = 0) and SkipZeroAmounts then
                        CurrReport.Skip();

                    InsertItemJnlLine();
                end;

                trigger OnPreDataItem()
                begin
                    SetRange("Posting Date", StartDate, EndDate);

                    if ("Country/Region".Code = CompanyInfo."Country/Region Code") or
                       ((CompanyInfo."Country/Region Code" = '') and not ShowBlank)
                    then begin
                        ShowBlank := true;
                        SetFilter("Country/Region Code", '%1|%2', "Country/Region".Code, '');
                    end else
                        SetRange("Country/Region Code", "Country/Region".Code);

                    IntrastatJnlLine2.SetCurrentKey("Source Type", "Source Entry No.");
                    IntrastatJnlLine2.SetRange("Source Type", IntrastatJnlLine2."Source Type"::"Item Entry");

                    with ValueEntry do begin
                        SetCurrentKey("Item Ledger Entry No.");
                        SetRange("Entry Type", "Entry Type"::"Direct Cost");
                        SetFilter(
                          "Item Ledger Entry Type", '%1|%2|%3',
                          "Item Ledger Entry Type"::Sale,
                          "Item Ledger Entry Type"::Purchase,
                          "Item Ledger Entry Type"::Transfer);
                    end;
                    OnAfterItemLedgerEntryOnPreDataItem("Item Ledger Entry");
                end;
            }
            dataitem("Job Ledger Entry"; "Job Ledger Entry")
            {
                DataItemLink = "Country/Region Code" = field(Code);
                DataItemTableView = sorting(Type, "Entry Type", "Country/Region Code", "Source Code", "Posting Date") where(Type = const(Item), "Source Code" = filter(<> ''), "Entry Type" = const(Usage));

                trigger OnAfterGetRecord()
                begin
                    IntrastatJnlLine2.SetRange("Source Entry No.", "Entry No.");
                    if IntrastatJnlLine2.FindFirst() or (CompanyInfo."Country/Region Code" = "Country/Region Code") then
                        CurrReport.Skip();

                    if IsJobService("Job Ledger Entry") then
                        CurrReport.Skip();

                    InsertJobLedgerLine();
                end;

                trigger OnPreDataItem()
                begin
                    SetRange("Posting Date", StartDate, EndDate);
                    IntrastatJnlLine2.SetCurrentKey("Source Type", "Source Entry No.");
                    IntrastatJnlLine2.SetRange("Source Type", IntrastatJnlLine2."Source Type"::"Job Entry");
                end;
            }
        }
        dataitem("Value Entry"; "Value Entry")
        {
            DataItemTableView = sorting("Entry No.");

            trigger OnAfterGetRecord()
            begin
                if ShowItemCharges then begin
                    IntrastatJnlLine2.SetRange("Source Entry No.", "Item Ledger Entry No.");
                    if IntrastatJnlLine2.FindFirst() then
                        CurrReport.Skip();

                    if "Item Ledger Entry".Get("Item Ledger Entry No.")
                    then begin
                        if "Item Ledger Entry"."Posting Date" in [StartDate .. EndDate] then
                            CurrReport.Skip();
                        if "Country/Region".Get("Item Ledger Entry"."Country/Region Code") then
                            if "Country/Region"."EU Country/Region Code" = '' then
                                CurrReport.Skip();
                        if not HasCrossedBorder("Item Ledger Entry") then
                            CurrReport.Skip();
                        InsertValueEntryLine();
                    end;
                end;
            end;

            trigger OnPreDataItem()
            begin
                SetRange("Posting Date", StartDate, EndDate);
                SetFilter("Item Charge No.", '<> %1', '');
                "Item Ledger Entry".SetRange("Posting Date");

                IntrastatJnlLine2.SetRange("Journal Batch Name", IntrastatJnlBatch.Name);
                IntrastatJnlLine2.SetCurrentKey("Source Type", "Source Entry No.");
                IntrastatJnlLine2.SetRange("Source Type", IntrastatJnlLine2."Source Type"::"Item Entry");
            end;
        }
    }

    requestpage
    {
        SaveValues = true;

        layout
        {
            area(content)
            {
                group(Options)
                {
                    Caption = 'Options';
                    field(StartingDate; StartDate)
                    {
                        ApplicationArea = Basic, Suite;
                        Caption = 'Starting Date';
                        ToolTip = 'Specifies the date from which the report or batch job processes information.';
                    }
                    field(EndingDate; EndDate)
                    {
                        ApplicationArea = Basic, Suite;
                        Caption = 'Ending Date';
                        ToolTip = 'Specifies the date to which the report or batch job processes information.';
                    }
                    field(IndirectCostPctReq; IndirectCostPctReq)
                    {
                        ApplicationArea = Basic, Suite;
                        Caption = 'Cost Regulation %';
                        DecimalPlaces = 0 : 5;
                        ToolTip = 'Specifies the cost regulation percentage to cover freight and insurance. The statistical value of every line in the journal is increased by this percentage.';
                    }
                }
                group(Additional)
                {
                    Caption = 'Additional';
                    field(SkipRecalcForZeros; SkipRecalcZeroAmounts)
                    {
                        ApplicationArea = Basic, Suite;
                        Caption = 'Skip Recalculation for Zero Amounts';
                        ToolTip = 'Specifies that lines without amounts will not be recalculated during the batch job.';
                    }
                    field(SkipZeros; SkipZeroAmounts)
                    {
                        ApplicationArea = Basic, Suite;
                        Caption = 'Skip Zero Amounts';
                        ToolTip = 'Specifies that item ledger entries without amounts will not be included in the batch job.';
                    }
                    field(ShowingItemCharges; ShowItemCharges)
                    {
                        ApplicationArea = Basic, Suite;
                        Caption = 'Show Item Charge Entries';
                        ToolTip = 'Specifies if you want to show direct costs that your company has assigned and posted as item charges.';
                    }
                }
            }
        }

        actions
        {
        }

        trigger OnOpenPage()
        begin
            IntraJnlTemplate.Get(IntrastatJnlLine."Journal Template Name");
            IntrastatJnlBatch.Get(IntrastatJnlLine."Journal Template Name", IntrastatJnlLine."Journal Batch Name");
            StartDate := IntrastatJnlBatch.GetStatisticsStartDate();
            EndDate := CalcDate('<+1M-1D>', StartDate);
        end;
    }

    labels
    {
    }

    trigger OnInitReport()
    begin
        CompanyInfo.FindFirst();
    end;

    trigger OnPreReport()
    begin
        IntrastatJnlLine.SetRange("Journal Template Name", IntrastatJnlLine."Journal Template Name");
        IntrastatJnlLine.SetRange("Journal Batch Name", IntrastatJnlLine."Journal Batch Name");
        IntrastatJnlLine.LockTable();
        if IntrastatJnlLine.FindLast() then;

        IntrastatJnlBatch.Get(IntrastatJnlLine."Journal Template Name", IntrastatJnlLine."Journal Batch Name");
        IntrastatJnlBatch.TestField(Reported, false);

        GetGLSetup();
        if IntrastatJnlBatch."Amounts in Add. Currency" then begin
            GLSetup.TestField("Additional Reporting Currency");
            AddCurrencyFactor :=
              CurrExchRate.ExchangeRate(EndDate, GLSetup."Additional Reporting Currency");
        end;
    end;

    var
        IntraJnlTemplate: Record "Intrastat Jnl. Template";
        IntrastatJnlLine: Record "Intrastat Jnl. Line";
        IntrastatJnlLine2: Record "Intrastat Jnl. Line";
        Item: Record Item;
        ValueEntry: Record "Value Entry";
        GLSetup: Record "General Ledger Setup";
        CurrExchRate: Record "Currency Exchange Rate";
        CompanyInfo: Record "Company Information";
        Currency: Record Currency;
        UOMMgt: Codeunit "Unit of Measure Management";
        TotalAmt: Decimal;
        AddCurrencyFactor: Decimal;
        AverageCost: Decimal;
        AverageCostACY: Decimal;
        GLSetupRead: Boolean;

        Text000: Label 'Prices including VAT cannot be calculated when %1 is %2.';

    protected var
        IntrastatJnlBatch: Record "Intrastat Jnl. Batch";
        StartDate: Date;
        EndDate: Date;
        IndirectCostPctReq: Decimal;
        SkipRecalcZeroAmounts: Boolean;
        SkipZeroAmounts: Boolean;
        ShowBlank: Boolean;
        ShowItemCharges: Boolean;

    procedure SetIntrastatJnlLine(NewIntrastatJnlLine: Record "Intrastat Jnl. Line")
    begin
        IntrastatJnlLine := NewIntrastatJnlLine;
    end;

    local procedure InsertItemJnlLine()
    var
        IsHandled: Boolean;
    begin
        GetGLSetup();
        with IntrastatJnlLine do begin
            Init();
            "Line No." := "Line No." + 10000;
            Date := "Item Ledger Entry"."Posting Date";
            "Country/Region Code" := "Item Ledger Entry"."Country/Region Code";
            "Transaction Type" := "Item Ledger Entry"."Transaction Type";
            "Transport Method" := "Item Ledger Entry"."Transport Method";
            "Source Entry No." := "Item Ledger Entry"."Entry No.";
            Quantity := "Item Ledger Entry".Quantity;
            "Document No." := "Item Ledger Entry"."Document No.";
            "Item No." := "Item Ledger Entry"."Item No.";
            "Entry/Exit Point" := "Item Ledger Entry"."Entry/Exit Point";
            Area := "Item Ledger Entry".Area;
            "Transaction Specification" := "Item Ledger Entry"."Transaction Specification";
            "Shpt. Method Code" := "Item Ledger Entry"."Shpt. Method Code";
            "Location Code" := "Item Ledger Entry"."Location Code";
            Amount := Round(Abs(TotalAmt), 1);

            if Quantity < 0 then
                Type := Type::Shipment
            else
                Type := Type::Receipt;

            SetCountryRegionCode(IntrastatJnlLine, "Item Ledger Entry");

            Validate("Item No.");
            Validate("Source Type", "Source Type"::"Item Entry");
            Validate(Quantity, Round(Abs(Quantity), UOMMgt.QtyRndPrecision()));
            Validate("Cost Regulation %", IndirectCostPctReq);

            IsHandled := false;
            OnBeforeInsertItemJnlLine(IntrastatJnlLine, "Item Ledger Entry", IsHandled);
            if not IsHandled then
                Insert();
        end;
    end;

    local procedure InsertJobLedgerLine()
    var
        IsHandled: Boolean;
    begin
        with IntrastatJnlLine do begin
            Init();
            "Line No." := "Line No." + 10000;

            Date := "Job Ledger Entry"."Posting Date";
            "Country/Region Code" := "Job Ledger Entry"."Country/Region Code";
            "Transaction Type" := "Job Ledger Entry"."Transaction Type";
            "Transport Method" := "Job Ledger Entry"."Transport Method";
            Quantity := "Job Ledger Entry"."Quantity (Base)";
            if Quantity > 0 then
                Type := Type::Shipment
            else
                Type := Type::Receipt;
            if IntrastatJnlBatch."Amounts in Add. Currency" then
                Amount := "Job Ledger Entry"."Add.-Currency Line Amount"
            else
                Amount := "Job Ledger Entry"."Line Amount (LCY)";
            "Source Entry No." := "Job Ledger Entry"."Entry No.";
            "Document No." := "Job Ledger Entry"."Document No.";
            "Item No." := "Job Ledger Entry"."No.";
            "Entry/Exit Point" := "Job Ledger Entry"."Entry/Exit Point";
            Area := "Job Ledger Entry".Area;
            "Transaction Specification" := "Job Ledger Entry"."Transaction Specification";
            "Shpt. Method Code" := "Job Ledger Entry"."Shpt. Method Code";
            "Location Code" := "Job Ledger Entry"."Location Code";

            if IntrastatJnlBatch."Amounts in Add. Currency" then
                Amount := Round(Abs(Amount), Currency."Amount Rounding Precision")
            else
                Amount := Round(Abs(Amount), GLSetup."Amount Rounding Precision");

            Validate("Item No.");
            Validate("Source Type", "Source Type"::"Job Entry");
            Validate(Quantity, Round(Abs(Quantity), 0.00001));

            Validate("Cost Regulation %", IndirectCostPctReq);

            IsHandled := false;
            OnBeforeInsertJobLedgerLine(IntrastatJnlLine, "Job Ledger Entry", IsHandled);
            if not IsHandled then
                Insert();
        end;
    end;

    local procedure GetGLSetup()
    begin
        if not GLSetupRead then begin
            GLSetup.Get();
            if GLSetup."Additional Reporting Currency" <> '' then
                Currency.Get(GLSetup."Additional Reporting Currency");
        end;
        GLSetupRead := true;
    end;

    local procedure CalculateAverageCost(var AverageCost: Decimal; var AverageCostACY: Decimal): Boolean
    var
        ValueEntry: Record "Value Entry";
        ItemLedgEntry: Record "Item Ledger Entry";
        AverageQty: Decimal;
    begin
        with ItemLedgEntry do begin
            SetCurrentKey("Item No.", "Entry Type");
            SetRange("Item No.", "Item Ledger Entry"."Item No.");
            SetRange("Entry Type", "Item Ledger Entry"."Entry Type");
            CalcSums(Quantity);
        end;

        with ValueEntry do begin
            SetCurrentKey("Item No.", "Posting Date", "Item Ledger Entry Type");
            SetRange("Item No.", "Item Ledger Entry"."Item No.");
            SetRange("Item Ledger Entry Type", "Item Ledger Entry"."Entry Type");
            CalcSums(
              "Cost Amount (Actual)",
              "Cost Amount (Expected)");
            "Cost Amount (Actual) (ACY)" :=
              CurrExchRate.ExchangeAmtLCYToFCY(
                EndDate, GLSetup."Additional Reporting Currency", "Cost Amount (Actual)", AddCurrencyFactor);
            "Cost Amount (Expected) (ACY)" :=
              CurrExchRate.ExchangeAmtLCYToFCY(
                EndDate, GLSetup."Additional Reporting Currency", "Cost Amount (Expected)", AddCurrencyFactor);
            AverageQty := ItemLedgEntry.Quantity;
            AverageCost := "Cost Amount (Actual)" + "Cost Amount (Expected)";
            AverageCostACY := "Cost Amount (Actual) (ACY)" + "Cost Amount (Expected) (ACY)";
        end;
        if AverageQty <> 0 then begin
            AverageCost := AverageCost / AverageQty;
            AverageCostACY := AverageCostACY / AverageQty;
            if (AverageCost < 0) or (AverageCostACY < 0) then begin
                AverageCost := 0;
                AverageCostACY := 0;
            end;
        end else begin
            AverageCost := 0;
            AverageCostACY := 0;
        end;

        exit(AverageQty >= 0);
    end;

    local procedure CountryOfOrigin(CountryRegionCode: Code[20]): Boolean
    var
        CountryRegion: Record "Country/Region";
    begin
        if ("Item Ledger Entry"."Country/Region Code" in [CompanyInfo."Country/Region Code", '']) =
           (CountryRegionCode in [CompanyInfo."Country/Region Code", ''])
        then
            exit(false);

        if CountryRegionCode <> '' then begin
            CountryRegion.Get(CountryRegionCode);
            if CountryRegion."Intrastat Code" = '' then
                exit(false);
        end;
        exit(true);
    end;

    local procedure HasCrossedBorder(ItemLedgEntry: Record "Item Ledger Entry") Result: Boolean
    var
        ItemLedgEntry2: Record "Item Ledger Entry";
        Location: Record Location;
        IsHandled: Boolean;
    begin
        IsHandled := false;
        OnBeforeHasCrossedBorder(ItemLedgEntry, Result, IsHandled);
        if IsHandled then
            exit(Result);

        with ItemLedgEntry do
            case true of
                "Drop Shipment":
                    begin
                        if ("Country/Region Code" = CompanyInfo."Country/Region Code") or
                           ("Country/Region Code" = '')
                        then
                            exit(false);
                        if "Applies-to Entry" = 0 then begin
                            ItemLedgEntry2.SetCurrentKey("Item No.", "Posting Date");
                            ItemLedgEntry2.SetRange("Item No.", "Item No.");
                            ItemLedgEntry2.SetRange("Posting Date", "Posting Date");
                            ItemLedgEntry2.SetRange("Applies-to Entry", "Entry No.");
                            ItemLedgEntry2.FindFirst();
                        end else
                            ItemLedgEntry2.Get("Applies-to Entry");
                        if (ItemLedgEntry2."Country/Region Code" <> CompanyInfo."Country/Region Code") and
                           (ItemLedgEntry2."Country/Region Code" <> '')
                        then
                            exit(false);
                    end;
                "Entry Type" = "Entry Type"::Transfer:
                    begin
                        if ("Country/Region Code" = CompanyInfo."Country/Region Code") or ("Country/Region Code" = '') then
                            exit(false);
                        case true of
                            (("Order Type" <> "Order Type"::Transfer) or ("Order No." = '')),
                            "Document Type" = "Document Type"::"Direct Transfer":
                                if Location.Get("Location Code") then
                                    if (Location."Country/Region Code" <> '') and (Location."Country/Region Code" <> CompanyInfo."Country/Region Code") then
                                        exit(false);
                            "Document Type" = "Document Type"::"Transfer Receipt":
                                begin
                                    ItemLedgEntry2.SetCurrentKey("Order Type", "Order No.");
                                    ItemLedgEntry2.SetRange("Order Type", "Order Type"::Transfer);
                                    ItemLedgEntry2.SetRange("Order No.", "Order No.");
                                    ItemLedgEntry2.SetRange("Document Type", ItemLedgEntry2."Document Type"::"Transfer Shipment");
                                    ItemLedgEntry2.SetFilter("Country/Region Code", '%1 | %2', '', CompanyInfo."Country/Region Code");
                                    ItemLedgEntry2.SetRange(Positive, true);
                                    if ItemLedgEntry2.IsEmpty() then
                                        exit(false);
                                end;
                            "Document Type" = "Document Type"::"Transfer Shipment":
                                begin
                                    if not ItemLedgEntry.Positive then
                                        exit;
                                    ItemLedgEntry2.SetCurrentKey("Order Type", "Order No.");
                                    ItemLedgEntry2.SetRange("Order Type", "Order Type"::Transfer);
                                    ItemLedgEntry2.SetRange("Order No.", "Order No.");
                                    ItemLedgEntry2.SetRange("Document Type", ItemLedgEntry2."Document Type"::"Transfer Receipt");
                                    ItemLedgEntry2.SetFilter("Country/Region Code", '%1 | %2', '', CompanyInfo."Country/Region Code");
                                    ItemLedgEntry2.SetRange(Positive, false);
                                    if ItemLedgEntry2.IsEmpty() then
                                        exit(false);
                                end;
                        end;
                    end;
                "Location Code" <> '':
                    begin
                        Location.Get("Location Code");
                        if not CountryOfOrigin(Location."Country/Region Code") then
                            exit(false);
                    end;
                else begin
                    if "Entry Type" = "Entry Type"::Purchase then
                        if not CountryOfOrigin(CompanyInfo."Ship-to Country/Region Code") then
                            exit(false);
                    if "Entry Type" = "Entry Type"::Sale then
                        if not CountryOfOrigin(CompanyInfo."Country/Region Code") then
                            exit(false);
                end;
            end;
        exit(true);
    end;

    local procedure InsertValueEntryLine()
    var
        Location: Record Location;
        IsHandled: Boolean;
    begin
        GetGLSetup();
        with IntrastatJnlLine do begin
            Init();
            "Line No." := "Line No." + 10000;
            Date := "Value Entry"."Posting Date";
            "Country/Region Code" := "Item Ledger Entry"."Country/Region Code";
            "Transaction Type" := "Item Ledger Entry"."Transaction Type";
            "Transport Method" := "Item Ledger Entry"."Transport Method";
            "Source Entry No." := "Item Ledger Entry"."Entry No.";
            Quantity := "Item Ledger Entry".Quantity;
            "Document No." := "Value Entry"."Document No.";
            "Item No." := "Item Ledger Entry"."Item No.";
            "Entry/Exit Point" := "Item Ledger Entry"."Entry/Exit Point";
            Area := "Item Ledger Entry".Area;
            "Transaction Specification" := "Item Ledger Entry"."Transaction Specification";
            "Location Code" := "Item Ledger Entry"."Location Code";
            Amount := Round(Abs("Value Entry"."Sales Amount (Actual)"), 1);

            SetJnlLineType(IntrastatJnlLine, "Value Entry"."Document Type");

            if ("Country/Region Code" = '') or
               ("Country/Region Code" = CompanyInfo."Country/Region Code")
            then
                if "Item Ledger Entry"."Location Code" = '' then
                    "Country/Region Code" := CompanyInfo."Ship-to Country/Region Code"
                else begin
                    Location.Get("Item Ledger Entry"."Location Code");
                    "Country/Region Code" := Location."Country/Region Code"
                end;

            Validate("Item No.");
            Validate("Source Type", "Source Type"::"Item Entry");
            Validate(Quantity, Round(Abs(Quantity), 0.00001));
            Validate("Cost Regulation %", IndirectCostPctReq);

            IsHandled := false;
            OnBeforeInsertValueEntryLine(IntrastatJnlLine, "Item Ledger Entry", IsHandled);
            if not IsHandled then
                Insert();
        end;
    end;

    local procedure IsService(ItemLedgEntry: Record "Item Ledger Entry"): Boolean
    var
        SalesShipmentLine: Record "Sales Shipment Line";
        ReturnReceiptLine: Record "Return Receipt Line";
        SalesCrMemoLine: Record "Sales Cr.Memo Line";
        SalesInvLine: Record "Sales Invoice Line";
        PurchRcptLine: Record "Purch. Rcpt. Line";
        ReturnShipmentLine: Record "Return Shipment Line";
        PurchInvLine: Record "Purch. Inv. Line";
        PurchCrMemoLine: Record "Purch. Cr. Memo Line";
        ServiceShipmentLine: Record "Service Shipment Line";
        ServiceCrMemoLine: Record "Service Cr.Memo Line";
        ServiceInvLine: Record "Service Invoice Line";
        VATPostingSetup: Record "VAT Posting Setup";
    begin
        with ItemLedgEntry do begin
            case true of
                "Document Type" = "Document Type"::"Sales Shipment":
                    if SalesShipmentLine.Get("Document No.", "Document Line No.") then
                        if VATPostingSetup.Get(SalesShipmentLine."VAT Bus. Posting Group", SalesShipmentLine."VAT Prod. Posting Group") then;
                "Document Type" = "Document Type"::"Sales Return Receipt":
                    if ReturnReceiptLine.Get("Document No.", "Document Line No.") then
                        if VATPostingSetup.Get(ReturnReceiptLine."VAT Bus. Posting Group", ReturnReceiptLine."VAT Prod. Posting Group") then;
                "Document Type" = "Document Type"::"Sales Invoice":
                    if SalesInvLine.Get("Document No.", "Document Line No.") then
                        if VATPostingSetup.Get(SalesInvLine."VAT Bus. Posting Group", SalesInvLine."VAT Prod. Posting Group") then;
                "Document Type" = "Document Type"::"Sales Credit Memo":
                    if SalesCrMemoLine.Get("Document No.", "Document Line No.") then
                        if VATPostingSetup.Get(SalesCrMemoLine."VAT Bus. Posting Group", SalesCrMemoLine."VAT Prod. Posting Group") then;
                "Document Type" = "Document Type"::"Purchase Receipt":
                    if PurchRcptLine.Get("Document No.", "Document Line No.") then
                        if VATPostingSetup.Get(PurchRcptLine."VAT Bus. Posting Group", PurchRcptLine."VAT Prod. Posting Group") then;
                "Document Type" = "Document Type"::"Purchase Return Shipment":
                    if ReturnShipmentLine.Get("Document No.", "Document Line No.") then
                        if VATPostingSetup.Get(ReturnShipmentLine."VAT Bus. Posting Group", ReturnShipmentLine."VAT Prod. Posting Group") then;
                "Document Type" = "Document Type"::"Purchase Invoice":
                    if PurchInvLine.Get("Document No.", "Document Line No.") then
                        if VATPostingSetup.Get(PurchInvLine."VAT Bus. Posting Group", PurchInvLine."VAT Prod. Posting Group") then;
                "Document Type" = "Document Type"::"Purchase Credit Memo":
                    if PurchCrMemoLine.Get("Document No.", "Document Line No.") then
                        if VATPostingSetup.Get(PurchCrMemoLine."VAT Bus. Posting Group", PurchCrMemoLine."VAT Prod. Posting Group") then;
                "Document Type" = "Document Type"::"Service Shipment":
                    if ServiceShipmentLine.Get("Document No.", "Document Line No.") then
                        if VATPostingSetup.Get(ServiceShipmentLine."VAT Bus. Posting Group", ServiceShipmentLine."VAT Prod. Posting Group") then;
                "Document Type" = "Document Type"::"Service Credit Memo":
                    if ServiceCrMemoLine.Get("Document No.", "Document Line No.") then
                        if VATPostingSetup.Get(ServiceCrMemoLine."VAT Bus. Posting Group", ServiceCrMemoLine."VAT Prod. Posting Group") then;
                "Document Type" = "Document Type"::"Service Invoice":
                    if ServiceInvLine.Get("Document No.", "Document Line No.") then
                        if VATPostingSetup.Get(ServiceInvLine."VAT Bus. Posting Group", ServiceInvLine."VAT Prod. Posting Group") then;
            end;
            exit(VATPostingSetup."EU Service");
        end;
    end;

    local procedure CalculateTotals(ItemLedgerEntry: Record "Item Ledger Entry")
    var
        VATPostingSetup: Record "VAT Posting Setup";
        TotalInvoicedQty: Decimal;
        TotalCostAmt: Decimal;
        TotalAmtExpected: Decimal;
        TotalCostAmtExpected: Decimal;
    begin
        with ItemLedgerEntry do begin
            TotalInvoicedQty := 0;
            TotalAmt := 0;
            TotalAmtExpected := 0;
            TotalCostAmt := 0;
            TotalCostAmtExpected := 0;

            ValueEntry.SetRange("Item Ledger Entry No.", "Entry No.");
            if ValueEntry.Find('-') then
                repeat
                    if not ((ValueEntry."Item Charge No." <> '') and
                            ((ValueEntry."Posting Date" > EndDate) or (ValueEntry."Posting Date" < StartDate)))
                    then begin
                        TotalInvoicedQty := TotalInvoicedQty + ValueEntry."Invoiced Quantity";
                        if not IntrastatJnlBatch."Amounts in Add. Currency" then begin
                            TotalAmt := TotalAmt + ValueEntry."Sales Amount (Actual)";
                            TotalCostAmt := TotalCostAmt + ValueEntry."Cost Amount (Actual)";
                            TotalAmtExpected := TotalAmtExpected + ValueEntry."Sales Amount (Expected)";
                            TotalCostAmtExpected := TotalCostAmtExpected + ValueEntry."Cost Amount (Expected)";
                        end else begin
                            TotalCostAmt := TotalCostAmt + ValueEntry."Cost Amount (Actual) (ACY)";
                            TotalCostAmtExpected := TotalCostAmtExpected + ValueEntry."Cost Amount (Expected) (ACY)";
                            if ValueEntry."Cost per Unit" <> 0 then begin
                                TotalAmt :=
                                  TotalAmt +
                                  ValueEntry."Sales Amount (Actual)" * ValueEntry."Cost per Unit (ACY)" / ValueEntry."Cost per Unit";
                                TotalAmtExpected :=
                                  TotalAmtExpected +
                                  ValueEntry."Sales Amount (Expected)" * ValueEntry."Cost per Unit (ACY)" / ValueEntry."Cost per Unit";
                            end else begin
                                TotalAmt :=
                                  TotalAmt +
                                  CurrExchRate.ExchangeAmtLCYToFCY(
                                    ValueEntry."Posting Date", GLSetup."Additional Reporting Currency",
                                    ValueEntry."Sales Amount (Actual)", AddCurrencyFactor);
                                TotalAmtExpected :=
                                  TotalAmtExpected +
                                  CurrExchRate.ExchangeAmtLCYToFCY(
                                    ValueEntry."Posting Date", GLSetup."Additional Reporting Currency",
                                    ValueEntry."Sales Amount (Expected)", AddCurrencyFactor);
                            end;
                        end;
                    end;
                until ValueEntry.Next() = 0;

            if Quantity <> TotalInvoicedQty then begin
                TotalAmt := TotalAmt + TotalAmtExpected;
                TotalCostAmt := TotalCostAmt + TotalCostAmtExpected;
            end;

            OnCalculateTotalsOnAfterSumTotals(ItemLedgerEntry, IntrastatJnlBatch, TotalAmt, TotalCostAmt);

            if "Entry Type" in ["Entry Type"::Purchase, "Entry Type"::Transfer] then begin
                if TotalCostAmt = 0 then begin
                    CalculateAverageCost(AverageCost, AverageCostACY);
                    if IntrastatJnlBatch."Amounts in Add. Currency" then
                        TotalCostAmt :=
                          TotalCostAmt + Quantity * AverageCostACY
                    else
                        TotalCostAmt :=
                          TotalCostAmt + Quantity * AverageCost;
                end;
                TotalAmt := TotalCostAmt;
            end;

            if (TotalAmt = 0) and ("Entry Type" = "Entry Type"::Sale) and (not SkipRecalcZeroAmounts) then begin
                if Item."No." <> "Item No." then
                    Item.Get("Item No.");
                if IntrastatJnlBatch."Amounts in Add. Currency" then
                    Item."Unit Price" :=
                      CurrExchRate.ExchangeAmtLCYToFCY(
                        EndDate, GLSetup."Additional Reporting Currency",
                        Item."Unit Price", AddCurrencyFactor);
                if Item."Price Includes VAT" then begin
                    VATPostingSetup.Get(Item."VAT Bus. Posting Gr. (Price)", Item."VAT Prod. Posting Group");
                    case VATPostingSetup."VAT Calculation Type" of
                        VATPostingSetup."VAT Calculation Type"::"Reverse Charge VAT":
                            VATPostingSetup."VAT %" := 0;
                        VATPostingSetup."VAT Calculation Type"::"Sales Tax":
                            Error(
                              Text000,
                              VATPostingSetup.FieldCaption("VAT Calculation Type"),
                              VATPostingSetup."VAT Calculation Type");
                    end;
                    TotalAmt :=
                      TotalAmt + Quantity *
                      (Item."Unit Price" / (1 + (VATPostingSetup."VAT %" / 100)));
                end else
                    TotalAmt := TotalAmt + Quantity * Item."Unit Price";
            end;
        end;

        OnAfterCalculateTotals(ItemLedgerEntry, IntrastatJnlBatch, TotalAmt, TotalCostAmt);
    end;

    local procedure IsJobService(JobLedgEntry: Record "Job Ledger Entry"): Boolean
    var
        Job: Record Job;
        Customer: Record Customer;
        VATPostingSetup: Record "VAT Posting Setup";
    begin
        if Job.Get(JobLedgEntry."Job No.") then
            if Customer.Get(Job."Bill-to Customer No.") then;
        if Item.Get(JobLedgEntry."No.") then
            if VATPostingSetup.Get(Customer."VAT Bus. Posting Group", Item."VAT Prod. Posting Group") then
                if VATPostingSetup."EU Service" then
                    exit(true);
        exit(false);
    end;

    local procedure IsServiceItem(ItemNo: Code[20]): Boolean
    var
        Item: Record Item;
    begin
        exit(Item.Get(ItemNo) and (Item.Type = Item.Type::Service));
    end;

    procedure InitializeRequest(NewStartDate: Date; NewEndDate: Date; NewIndirectCostPctReq: Decimal)
    begin
        StartDate := NewStartDate;
        EndDate := NewEndDate;
        IndirectCostPctReq := NewIndirectCostPctReq;
    end;

    local procedure IsItemLedgerEntryCorrected(ItemLedgerEntryCorrection: Record "Item Ledger Entry"; ItemLedgerEntryNo: Integer): Boolean
    var
        ItemApplicationEntry: Record "Item Application Entry";
    begin
        ItemApplicationEntry.SetRange("Item Ledger Entry No.", ItemLedgerEntryCorrection."Entry No.");
        case ItemLedgerEntryCorrection."Document Type" of
            ItemLedgerEntryCorrection."Document Type"::"Sales Shipment",
          ItemLedgerEntryCorrection."Document Type"::"Purchase Return Shipment":
                ItemApplicationEntry.SetRange("Outbound Item Entry No.", ItemLedgerEntryNo);
            ItemLedgerEntryCorrection."Document Type"::"Purchase Receipt",
          ItemLedgerEntryCorrection."Document Type"::"Sales Return Receipt":
                ItemApplicationEntry.SetRange("Inbound Item Entry No.", ItemLedgerEntryNo);
        end;
        exit(not ItemApplicationEntry.IsEmpty);
    end;

    local procedure SetCountryRegionCode(var IntrastatJnlLine: Record "Intrastat Jnl. Line"; ItemLedgerEntry: Record "Item Ledger Entry")
    var
        Location: Record Location;
    begin
        with IntrastatJnlLine do
            if ("Country/Region Code" = '') or
               ("Country/Region Code" = CompanyInfo."Country/Region Code")
            then
                if ItemLedgerEntry."Location Code" = '' then
                    "Country/Region Code" := CompanyInfo."Ship-to Country/Region Code"
                else begin
                    Location.Get(ItemLedgerEntry."Location Code");
                    "Country/Region Code" := Location."Country/Region Code"
                end;
    end;

    local procedure SetJnlLineType(var IntrastatJnlLine: Record "Intrastat Jnl. Line"; ValueEntryDocumentType: Enum "Item Ledger Document Type")
    begin
        with IntrastatJnlLine do
            if Quantity < 0 then begin
                if ValueEntryDocumentType = "Value Entry"."Document Type"::"Sales Credit Memo" then
                    Type := Type::Receipt
                else
                    Type := Type::Shipment
            end else
                if ValueEntryDocumentType = "Value Entry"."Document Type"::"Purchase Credit Memo" then
                    Type := Type::Shipment
                else
                    Type := Type::Receipt;
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterCalculateTotals(var ItemLedgerEntry: Record "Item Ledger Entry"; IntrastatJnlBatch: Record "Intrastat Jnl. Batch"; var TotalAmt: Decimal; var TotalCostAmt: Decimal)
    begin
    end;

    [IntegrationEvent(true, false)]
    local procedure OnAfterItemLedgerEntryOnPreDataItem(var ItemLedgerEntry: Record "Item Ledger Entry")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeHasCrossedBorder(ItemLedgerEntry: Record "Item Ledger Entry"; var Result: Boolean; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeInsertItemJnlLine(var IntrastatJnlLine: Record "Intrastat Jnl. Line"; ItemLedgerEntry: Record "Item Ledger Entry"; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeInsertJobLedgerLine(var IntrastatJnlLine: Record "Intrastat Jnl. Line"; JobLedgerEntry: Record "Job Ledger Entry"; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeInsertValueEntryLine(var IntrastatJnlLine: Record "Intrastat Jnl. Line"; ItemLedgerEntry: Record "Item Ledger Entry"; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnCalculateTotalsOnAfterSumTotals(var ItemLedgerEntry: Record "Item Ledger Entry"; IntrastatJnlBatch: Record "Intrastat Jnl. Batch"; var TotalAmt: Decimal; var TotalCostAmt: Decimal)
    begin
    end;
}
#endif
