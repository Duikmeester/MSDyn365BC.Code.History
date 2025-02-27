﻿namespace Microsoft.Warehouse.Request;

using Microsoft.Assembly.Document;
using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Transfer;
using Microsoft.Manufacturing.Document;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Project.Planning;
using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Microsoft.Service.Document;
using Microsoft.Warehouse.Activity;
using Microsoft.Warehouse.Document;
using Microsoft.Warehouse.History;
using Microsoft.Warehouse.InternalDocument;
using Microsoft.Warehouse.Journal;
using Microsoft.Warehouse.Worksheet;

codeunit 5775 "Whse. Management"
{

    trigger OnRun()
    begin
    end;

    var
        UOMMgt: Codeunit "Unit of Measure Management";

        Text000: Label 'The Source Document is not defined.';

    procedure GetWhseActivSourceDocument(SourceType: Integer; SourceSubtype: Integer): Enum "Warehouse Activity Source Document"
    begin
        exit(GetSourceDocumentType(SourceType, SourceSubtype));
    end;

    procedure GetWhseJnlSourceDocument(SourceType: Integer; SourceSubtype: Integer) SourceDocument: Enum "Warehouse Journal Source Document"
    begin
        exit(GetSourceDocumentType(SourceType, SourceSubtype));
    end;

    procedure GetWhseRqstSourceDocument(SourceType: Integer; SourceSubtype: Integer) SourceDocument: Enum "Warehouse Request Source Document"
    var
        WhseJournalSourceDocument: Enum "Warehouse Journal Source Document";
    begin
        WhseJournalSourceDocument := GetSourceDocumentType(SourceType, SourceSubtype);
        case WhseJournalSourceDocument of
            WhseJournalSourceDocument::"S. Order":
                SourceDocument := "Warehouse Request Source Document"::"Sales Order";
            WhseJournalSourceDocument::"S. Return Order":
                SourceDocument := "Warehouse Request Source Document"::"Sales Return Order";
            WhseJournalSourceDocument::"P. Order":
                SourceDocument := "Warehouse Request Source Document"::"Purchase Order";
            WhseJournalSourceDocument::"P. Return Order":
                SourceDocument := "Warehouse Request Source Document"::"Purchase Return Order";
            WhseJournalSourceDocument::"Inb. Transfer":
                SourceDocument := "Warehouse Request Source Document"::"Inbound Transfer";
            WhseJournalSourceDocument::"Outb. Transfer":
                SourceDocument := "Warehouse Request Source Document"::"Outbound Transfer";
            WhseJournalSourceDocument::"Prod. Consumption":
                SourceDocument := "Warehouse Request Source Document"::"Prod. Consumption";
            WhseJournalSourceDocument::"Item Jnl.":
                SourceDocument := "Warehouse Request Source Document"::"Prod. Output";
            WhseJournalSourceDocument::"Serv. Order":
                SourceDocument := "Warehouse Request Source Document"::"Service Order";
            WhseJournalSourceDocument::"Assembly Order":
                SourceDocument := "Warehouse Request Source Document"::"Assembly Order";
            WhseJournalSourceDocument::"Assembly Consumption":
                SourceDocument := "Warehouse Request Source Document"::"Assembly Consumption";
            WhseJournalSourceDocument::"Job Usage":
                SourceDocument := "Warehouse Request Source Document"::"Job Usage";
            else
                SourceDocument := WhseJournalSourceDocument;
        end;
    end;

    procedure GetSourceDocumentType(SourceType: Integer; SourceSubtype: Integer): Enum "Warehouse Journal Source Document"
    var
#if not CLEAN21
        SourceDocument: Option;
#endif
        SourceDocumentType: Enum "Warehouse Journal Source Document";
        IsHandled: Boolean;
    begin
        IsHandled := false;
        OnBeforeGetSourceDocumentType(SourceType, SourceSubtype, SourceDocumentType, IsHandled);
        if IsHandled then
            exit(SourceDocumentType);

#if not CLEAN21
        IsHandled := false;
        OnBeforeGetSourceDocument(SourceType, SourceSubtype, SourceDocument, IsHandled);
        if IsHandled then
            exit("Warehouse Journal Source Document".FromInteger(SourceDocument));
#endif

        case SourceType of
            Database::"Sales Line":
                case SourceSubtype of
                    1:
                        exit("Warehouse Journal Source Document"::"S. Order");
                    2:
                        exit("Warehouse Journal Source Document"::"S. Invoice");
                    3:
                        exit("Warehouse Journal Source Document"::"S. Credit Memo");
                    5:
                        exit("Warehouse Journal Source Document"::"S. Return Order");
                end;
            Database::"Purchase Line":
                case SourceSubtype of
                    1:
                        exit("Warehouse Journal Source Document"::"P. Order");
                    2:
                        exit("Warehouse Journal Source Document"::"P. Invoice");
                    3:
                        exit("Warehouse Journal Source Document"::"P. Credit Memo");
                    5:
                        exit("Warehouse Journal Source Document"::"P. Return Order");
                end;
            Database::"Service Line":
                exit("Warehouse Journal Source Document"::"Serv. Order");
            Database::"Prod. Order Component":
                exit("Warehouse Journal Source Document"::"Prod. Consumption");
            Database::"Assembly Line":
                exit("Warehouse Journal Source Document"::"Assembly Consumption");
            Database::"Assembly Header":
                exit("Warehouse Journal Source Document"::"Assembly Order");
            Database::"Transfer Line":
                case SourceSubtype of
                    0:
                        exit("Warehouse Journal Source Document"::"Outb. Transfer");
                    1:
                        exit("Warehouse Journal Source Document"::"Inb. Transfer");
                end;
            Database::"Item Journal Line":
                case SourceSubtype of
                    0:
                        exit("Warehouse Journal Source Document"::"Item Jnl.");
                    1:
                        exit("Warehouse Journal Source Document"::"Reclass. Jnl.");
                    2:
                        exit("Warehouse Journal Source Document"::"Phys. Invt. Jnl.");
                    4:
                        exit("Warehouse Journal Source Document"::"Consumption Jnl.");
                    5:
                        exit("Warehouse Journal Source Document"::"Output Jnl.");
                end;
            Database::"Job Journal Line":
                exit("Warehouse Journal Source Document"::"Job Jnl.");
            Database::Job:
                exit("Warehouse Journal Source Document"::"Job Usage");
        end;

        IsHandled := false;
        OnAfterGetSourceDocumentType(SourceType, SourceSubtype, SourceDocumentType, IsHandled);
        if IsHandled then
            exit(SourceDocumentType);

#if not CLEAN21
        IsHandled := false;
        OnAfterGetSourceDocument(SourceType, SourceSubtype, SourceDocument, IsHandled);
        if IsHandled then
            exit("Warehouse Journal Source Document".FromInteger(SourceDocument));
#endif

        Error(Text000);
    end;

    procedure GetSourceDocument(SourceType: Integer; SourceSubtype: Integer): Integer
    begin
        exit(GetSourceDocumentType(SourceType, SourceSubtype).AsInteger());
    end;

    procedure GetJournalSourceDocument(SourceType: Integer; SourceSubtype: Integer) SourceDocument: Enum "Warehouse Journal Source Document"
    var
        IsHandled: Boolean;
    begin
        IsHandled := false;
        OnBeforeGetJournalSourceDocument(SourceType, SourceSubtype, SourceDocument, IsHandled);
        if IsHandled then
            exit(SourceDocument);

        case SourceType of
            Database::"Sales Line":
                case SourceSubtype of
                    1:
                        exit(SourceDocument::"S. Order");
                    2:
                        exit(SourceDocument::"S. Invoice");
                    3:
                        exit(SourceDocument::"S. Credit Memo");
                    5:
                        exit(SourceDocument::"S. Return Order");
                end;
            Database::"Purchase Line":
                case SourceSubtype of
                    1:
                        exit(SourceDocument::"P. Order");
                    2:
                        exit(SourceDocument::"P. Invoice");
                    3:
                        exit(SourceDocument::"P. Credit Memo");
                    5:
                        exit(SourceDocument::"P. Return Order");
                end;
            Database::"Service Line":
                exit(SourceDocument::"Serv. Order");
            Database::"Prod. Order Component":
                exit(SourceDocument::"Prod. Consumption");
            Database::"Assembly Line":
                exit(SourceDocument::"Assembly Consumption");
            Database::"Assembly Header":
                exit(SourceDocument::"Assembly Order");
            Database::"Transfer Line":
                case SourceSubtype of
                    0:
                        exit(SourceDocument::"Outb. Transfer");
                    1:
                        exit(SourceDocument::"Inb. Transfer");
                end;
            Database::"Item Journal Line":
                case SourceSubtype of
                    0:
                        exit(SourceDocument::"Item Jnl.");
                    1:
                        exit(SourceDocument::"Reclass. Jnl.");
                    2:
                        exit(SourceDocument::"Phys. Invt. Jnl.");
                    4:
                        exit(SourceDocument::"Consumption Jnl.");
                    5:
                        exit(SourceDocument::"Output Jnl.");
                end;
            Database::"Job Journal Line":
                exit(SourceDocument::"Job Jnl.");
        end;
        OnAfterGetJournalSourceDocument(SourceType, SourceSubtype, SourceDocument, IsHandled);
        if IsHandled then
            exit(SourceDocument);
        Error(Text000);
    end;

    procedure GetSourceType(WhseWkshLine: Record "Whse. Worksheet Line") SourceType: Integer
    var
        IsHandled: Boolean;
    begin
        IsHandled := false;
        OnBeforeGetSourceType(WhseWkshLine, SourceType, IsHandled);
        if IsHandled then
            exit(SourceType);

        with WhseWkshLine do
            case "Whse. Document Type" of
                "Whse. Document Type"::Receipt:
                    SourceType := Database::"Posted Whse. Receipt Line";
                "Whse. Document Type"::Shipment:
                    SourceType := Database::"Warehouse Shipment Line";
                "Whse. Document Type"::Production:
                    SourceType := Database::"Prod. Order Component";
                "Whse. Document Type"::Assembly:
                    SourceType := Database::"Assembly Line";
                "Whse. Document Type"::"Internal Put-away":
                    SourceType := Database::"Whse. Internal Put-away Line";
                "Whse. Document Type"::"Internal Pick":
                    SourceType := Database::"Whse. Internal Pick Line";
                "Whse. Document Type"::Job:
                    SourceType := Database::Job;
            end;
    end;

    procedure GetOutboundDocLineQtyOtsdg(SourceType: Integer; SourceSubType: Integer; SourceNo: Code[20]; SourceLineNo: Integer; SourceSubLineNo: Integer; var QtyOutstanding: Decimal; var QtyBaseOutstanding: Decimal)
    var
        WhseShptLine: Record "Warehouse Shipment Line";
    begin
        with WhseShptLine do begin
            SetCurrentKey("Source Type");
            SetRange("Source Type", SourceType);
            SetRange("Source Subtype", SourceSubType);
            SetRange("Source No.", SourceNo);
            SetRange("Source Line No.", SourceLineNo);
            if FindFirst() then begin
                CalcFields("Pick Qty. (Base)", "Pick Qty.");
                CalcSums(Quantity, "Qty. (Base)");
                QtyOutstanding := Quantity - "Pick Qty." - "Qty. Picked";
                QtyBaseOutstanding := "Qty. (Base)" - "Pick Qty. (Base)" - "Qty. Picked (Base)";
            end else
                GetSrcDocLineQtyOutstanding(SourceType, SourceSubType, SourceNo,
                  SourceLineNo, SourceSubLineNo, QtyOutstanding, QtyBaseOutstanding);
        end;
    end;

    local procedure GetSrcDocLineQtyOutstanding(SourceType: Integer; SourceSubType: Integer; SourceNo: Code[20]; SourceLineNo: Integer; SourceSubLineNo: Integer; var QtyOutstanding: Decimal; var QtyBaseOutstanding: Decimal)
    var
        SalesLine: Record "Sales Line";
        PurchaseLine: Record "Purchase Line";
        TransferLine: Record "Transfer Line";
        ServiceLine: Record "Service Line";
        ProdOrderComp: Record "Prod. Order Component";
        AssemblyLine: Record "Assembly Line";
        ProdOrderLine: Record "Prod. Order Line";
        JobPlanningLine: Record "Job Planning Line";
    begin
        case SourceType of
            Database::"Sales Line":
                if SalesLine.Get(SourceSubType, SourceNo, SourceLineNo) then begin
                    QtyOutstanding := SalesLine."Outstanding Quantity";
                    QtyBaseOutstanding := SalesLine."Outstanding Qty. (Base)";
                end;
            Database::"Purchase Line":
                if PurchaseLine.Get(SourceSubType, SourceNo, SourceLineNo) then begin
                    QtyOutstanding := PurchaseLine."Outstanding Quantity";
                    QtyBaseOutstanding := PurchaseLine."Outstanding Qty. (Base)";
                end;
            Database::"Transfer Line":
                if TransferLine.Get(SourceNo, SourceLineNo) then
                    case SourceSubType of
                        0: // Direction = Outbound
                            begin
                                QtyOutstanding :=
                                  Round(
                                    TransferLine."Whse Outbnd. Otsdg. Qty (Base)" / (QtyOutstanding / QtyBaseOutstanding),
                                    UOMMgt.QtyRndPrecision());
                                QtyBaseOutstanding := TransferLine."Whse Outbnd. Otsdg. Qty (Base)";
                            end;
                        1: // Direction = Inbound
                            begin
                                QtyOutstanding :=
                                  Round(
                                    TransferLine."Whse. Inbnd. Otsdg. Qty (Base)" / (QtyOutstanding / QtyBaseOutstanding),
                                    UOMMgt.QtyRndPrecision());
                                QtyBaseOutstanding := TransferLine."Whse. Inbnd. Otsdg. Qty (Base)";
                            end;
                    end;
            Database::"Service Line":
                if ServiceLine.Get(SourceSubType, SourceNo, SourceLineNo) then begin
                    QtyOutstanding := ServiceLine."Outstanding Quantity";
                    QtyBaseOutstanding := ServiceLine."Outstanding Qty. (Base)";
                end;
            Database::"Prod. Order Component":
                if ProdOrderComp.Get(SourceSubType, SourceNo, SourceLineNo, SourceSubLineNo) then begin
                    QtyOutstanding := ProdOrderComp."Remaining Quantity";
                    QtyBaseOutstanding := ProdOrderComp."Remaining Qty. (Base)";
                end;
            Database::"Assembly Line":
                if AssemblyLine.Get(SourceSubType, SourceNo, SourceLineNo) then begin
                    QtyOutstanding := AssemblyLine."Remaining Quantity";
                    QtyBaseOutstanding := AssemblyLine."Remaining Quantity (Base)";
                end;
            Database::"Prod. Order Line":
                if ProdOrderLine.Get(SourceSubType, SourceNo, SourceLineNo) then begin
                    QtyOutstanding := ProdOrderLine."Remaining Quantity";
                    QtyBaseOutstanding := ProdOrderLine."Remaining Qty. (Base)";
                end;
            Database::Job, Database::"Job Planning Line":
                begin
                    JobPlanningLine.Setrange(Status, "Job Planning Line Status"::Order);
                    JobPlanningLine.SetRange("Job No.", SourceNo);
                    JobPlanningLine.SetRange("Job Contract Entry No.", SourceLineNo);
                    if JobPlanningLine.FindFirst() then begin
                        QtyOutstanding := JobPlanningLine."Remaining Qty.";
                        QtyBaseOutstanding := JobPlanningLine."Remaining Qty. (Base)";
                    end;
                end;
            else begin
                QtyOutstanding := 0;
                QtyBaseOutstanding := 0;
            end;
        end;

        OnAfterGetSrcDocLineQtyOutstanding(
          SourceType, SourceSubType, SourceNo, SourceLineNo, SourceSubLineNo, QtyOutstanding, QtyBaseOutstanding);
    end;

    procedure SetSourceFilterForWhseRcptLine(var WarehouseReceiptLine: Record "Warehouse Receipt Line"; SourceType: Integer; SourceSubType: Option; SourceNo: Code[20]; SourceLineNo: Integer; SetKey: Boolean)
    begin
        with WarehouseReceiptLine do begin
            if SetKey then
                SetCurrentKey("Source Type", "Source Subtype", "Source No.", "Source Line No.");
            SetRange("Source Type", SourceType);
            if SourceSubType >= 0 then
                SetRange("Source Subtype", SourceSubType);
            SetRange("Source No.", SourceNo);
            if SourceLineNo >= 0 then
                SetRange("Source Line No.", SourceLineNo);
        end;

        OnAfterSetSourceFilterForWhseRcptLine(WarehouseReceiptLine, SourceType, SourceSubType, SourceNo, SourceLineNo, SetKey);
    end;

    procedure SetSourceFilterForWhseActivityLine(var WarehouseActivityLine: Record "Warehouse Activity Line"; SourceType: Integer; SourceSubType: Option; SourceNo: Code[20]; SourceLineNo: Integer; SetKey: Boolean)
    begin
        with WarehouseActivityLine do begin
            if SetKey then
                SetCurrentKey("Source Type", "Source Subtype", "Source No.", "Source Line No.");
            SetRange("Source Type", SourceType);
            if SourceSubType >= 0 then
                SetRange("Source Subtype", SourceSubType);
            SetRange("Source No.", SourceNo);
            if SourceLineNo >= 0 then
                SetRange("Source Line No.", SourceLineNo);
        end;
    end;

    procedure SetSourceFilterForWhseShptLine(var WarehouseShipmentLine: Record "Warehouse Shipment Line"; SourceType: Integer; SourceSubType: Option; SourceNo: Code[20]; SourceLineNo: Integer; SetKey: Boolean)
    begin
        with WarehouseShipmentLine do begin
            if SetKey then
                SetCurrentKey("Source Type", "Source Subtype", "Source No.", "Source Line No.");
            SetRange("Source Type", SourceType);
            if SourceSubType >= 0 then
                SetRange("Source Subtype", SourceSubType);
            SetRange("Source No.", SourceNo);
            if SourceLineNo >= 0 then
                SetRange("Source Line No.", SourceLineNo);
        end;

        OnAfterSetSourceFilterForWhseShptLine(WarehouseShipmentLine, SourceType, SourceSubType, SourceNo, SourceLineNo, SetKey);
    end;

    procedure SetSourceFilterForPostedWhseRcptLine(var PostedWhseReceiptLine: Record "Posted Whse. Receipt Line"; SourceType: Integer; SourceSubType: Option; SourceNo: Code[20]; SourceLineNo: Integer; SetKey: Boolean)
    begin
        with PostedWhseReceiptLine do begin
            if SetKey then
                SetCurrentKey("Source Type", "Source Subtype", "Source No.", "Source Line No.");
            SetRange("Source Type", SourceType);
            if SourceSubType >= 0 then
                SetRange("Source Subtype", SourceSubType);
            SetRange("Source No.", SourceNo);
            if SourceLineNo >= 0 then
                SetRange("Source Line No.", SourceLineNo);
        end;

        OnAfterSetSourceFilterForPostedWhseRcptLine(PostedWhseReceiptLine, SourceType, SourceSubType, SourceNo, SourceLineNo, SetKey);
    end;

    procedure SetSourceFilterForPostedWhseShptLine(var PostedWhseShipmentLine: Record "Posted Whse. Shipment Line"; SourceType: Integer; SourceSubType: Option; SourceNo: Code[20]; SourceLineNo: Integer; SetKey: Boolean)
    begin
        with PostedWhseShipmentLine do begin
            if SetKey then
                SetCurrentKey("Source Type", "Source Subtype", "Source No.", "Source Line No.");
            SetRange("Source Type", SourceType);
            if SourceSubType >= 0 then
                SetRange("Source Subtype", SourceSubType);
            SetRange("Source No.", SourceNo);
            if SourceLineNo >= 0 then
                SetRange("Source Line No.", SourceLineNo);
        end;

        OnAfterSetSourceFilterForPostedWhseShptLine(PostedWhseShipmentLine, SourceType, SourceSubType, SourceNo, SourceLineNo, SetKey);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterGetSrcDocLineQtyOutstanding(SourceType: Integer; SourceSubType: Integer; SourceNo: Code[20]; SourceLineNo: Integer; SourceSubLineNo: Integer; var QtyOutstanding: Decimal; var QtyBaseOutstanding: Decimal)
    begin
    end;

#if not CLEAN21
    [Obsolete('Replaced by event OnAfterGetSourceDocumentType()', '21.0')]
    [IntegrationEvent(false, false)]
    local procedure OnAfterGetSourceDocument(SourceType: Integer; SourceSubtype: Integer; var SourceDocument: Option; var IsHandled: Boolean)
    begin
    end;
#endif

    [IntegrationEvent(false, false)]
    local procedure OnAfterGetSourceDocumentType(SourceType: Integer; SourceSubtype: Integer; var SourceDocument: Enum "Warehouse Journal Source Document"; var IsHandled: Boolean)
    begin
    end;

#if not CLEAN21
    [Obsolete('Replaced by event OnBeforeGetSourceDocumentType()', '21.0')]
    [IntegrationEvent(false, false)]
    local procedure OnBeforeGetSourceDocument(SourceType: Integer; SourceSubtype: Integer; var SourceDocument: Option; var IsHandled: Boolean)
    begin
    end;
#endif

    [IntegrationEvent(false, false)]
    local procedure OnBeforeGetSourceDocumentType(SourceType: Integer; SourceSubtype: Integer; var SourceDocumentType: Enum "Warehouse Journal Source Document"; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeGetSourceType(WhseWorksheetLine: Record "Whse. Worksheet Line"; var SourceType: Integer; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterGetJournalSourceDocument(SourceType: Integer; SourceSubtype: Integer; var SourceDocument: Enum "Warehouse Journal Source Document"; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterSetSourceFilterForWhseRcptLine(var WarehouseReceiptLine: Record "Warehouse Receipt Line"; SourceType: Integer; SourceSubType: Option; SourceNo: Code[20]; SourceLineNo: Integer; SetKey: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterSetSourceFilterForWhseShptLine(var WarehouseShipmentLine: Record "Warehouse Shipment Line"; SourceType: Integer; SourceSubType: Option; SourceNo: Code[20]; SourceLineNo: Integer; SetKey: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterSetSourceFilterForPostedWhseRcptLine(var PostedWhseReceiptLine: Record "Posted Whse. Receipt Line"; SourceType: Integer; SourceSubType: Option; SourceNo: Code[20]; SourceLineNo: Integer; SetKey: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterSetSourceFilterForPostedWhseShptLine(var PostedWhseShipmentLine: Record "Posted Whse. Shipment Line"; SourceType: Integer; SourceSubType: Option; SourceNo: Code[20]; SourceLineNo: Integer; SetKey: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeGetJournalSourceDocument(SourceType: Integer; SourceSubtype: Integer; var SourceDocument: Enum "Warehouse Journal Source Document"; var IsHandled: Boolean)
    begin
    end;
}

