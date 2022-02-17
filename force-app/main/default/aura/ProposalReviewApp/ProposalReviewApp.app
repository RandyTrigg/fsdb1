<aura:application extends="force:slds">

    <aura:attribute name="proposalId" required="true" type="String" />
    <c:ProposalEdit proposalId="{!v.proposalId}" />

</aura:application>