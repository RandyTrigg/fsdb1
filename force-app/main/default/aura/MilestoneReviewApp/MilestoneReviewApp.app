<aura:application extends="force:slds">

    <aura:attribute name="milestoneId" required="true" type="String" />
    <c:MilestoneEdit milestoneId="{!v.milestoneId}" />

</aura:application>