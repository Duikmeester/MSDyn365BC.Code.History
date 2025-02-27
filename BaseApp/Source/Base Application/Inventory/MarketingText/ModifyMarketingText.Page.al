// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.Inventory.MarketingText;

using Microsoft.Inventory.Item;
using System.Text;

page 5839 "Modify Marketing Text"
{
    Caption = 'Edit Marketing Text';
    DelayedInsert = true;
    SourceTableTemporary = true;
    InsertAllowed = false;
    DeleteAllowed = false;
    LinksAllowed = false;
    PageType = StandardDialog;
    Extensible = false;
    SourceTable = "Entity Text";
    DataCaptionExpression = ItemDescription;

    layout
    {
        area(content)
        {
            group(EntityTextGroup)
            {
                ShowCaption = false;
                field("Entity Text Editor"; EntityTextContent)
                {
                    MultiLine = true;
                    ApplicationArea = All;
                    ExtendedDatatype = RichContent;
                    Caption = 'Marketing Text';
                    ToolTip = 'Specifies the rich text content of the text.';
                    StyleExpr = false;
                }
            }

            grid(CopilotActionGrid)
            {
                group(CopilotLink)
                {
                    Visible = IsCopilotEnabled;
                    InstructionalText = 'Get help writing engaging texts based on the item''s attributes';
                    ShowCaption = false;
                    field(CopilotPrompt; DraftWithCopilotTxt)
                    {
                        Visible = IsCopilotEnabled;
                        Editable = false;
                        ShowCaption = false;
                        ApplicationArea = All;

                        trigger OnDrillDown()
                        var
                            MarketingText: Codeunit "Marketing Text";
                            Action: Action;
                            ConfirmReplace: Boolean;

                        begin
                            if not EntityText.IsEnabled(false) then
                                exit;

                            if not (EntityTextContent = '') then begin
                                ConfirmReplace := Confirm(ConfirmTxt, false);
                                if not ConfirmReplace then exit;
                            end;

                            MarketingText.CreateWithCopilot(Rec, PromptMode::Prompt, Action);
                            if Action = Action::OK then begin
                                EntityTextContent := EntityText.GetText(Rec);
                                CurrPage.Update(false);
                            end;
                        end;
                    }
                }
            }
        }
    }

    trigger OnInit()
    var
        MarketingText: Codeunit "Marketing Text";
    begin
        IsCopilotEnabled := MarketingText.IsMarketingTextVisible() and EntityText.CanSuggest();
    end;

    trigger OnAfterGetCurrRecord()
    var
        Item: Record Item;
    begin
        if HasLoaded then
            exit;

        Item.GetBySystemId(Rec."Source System Id");
        ItemDescription := Item.Description;
        EntityTextContent := EntityText.GetText(Rec);
        HasLoaded := true;
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        if not (CloseAction in [Action::OK, Action::LookupOK]) then
            exit(true);
        EntityText.UpdateText(Rec, EntityTextContent);
        Rec.Modify();
    end;

    var
        EntityText: Codeunit "Entity Text";
        ItemDescription: Text;
        EntityTextContent: Text;
        IsCopilotEnabled: Boolean;
        HasLoaded: Boolean;
        ConfirmTxt: Label 'If you generate a new text and keep it, the current text is replaced. Do you want to continue?';
        DraftWithCopilotTxt: Label 'Draft with Copilot';
}