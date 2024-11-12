var vReturn;

Ext.define('EAM.custom.external_1uinvl', {
	extend: 'EAM.custom.AbstractExtensibleFramework',
	getSelectors: function () {
		
		var me = this;
		
		return {
		
			'[extensibleFramework] [tabName=LST]':  {
				 beforerender: function () {
                     vGrid_Event_Bind = 0;
					 console.log("1uinvl beforerender");
					 try {
						 vReturn= getURLVar("return");
						 console.log(vReturn);
					 }catch (err) {
						//console.log(err);
					}
				 },//beforerender
				 
				 afterlayout: function () {
					 console.log("1uinvl afterlayout");
					 console.log('1uinvl IsHyperLink:' + EAM.getApplication().isHyperlink);
					 try{
						 if (EAM.getApplication().isHyperlink){
                            if (vGrid_Event_Bind == 0) {
                                var vGridView=EAM.Utils.getScreen().getCurrentTab().getGrid().getView();
							 
							 vGridView.on('itemdblclick',function(e,rec) {
								   var vBtn = Ext.ComponentQuery.query('[action=returnModalValue]')[0].btnEl.dom;
								   console.log(vBtn);
								   console.log(rec.data);
				                   var vOrigReceipt = rec.data['ivl_udfchar25'];
								   var vOrigReceiptLine = rec.data['ivl_udfchar24'];
								   var vOrigReceiptRef = rec.data['ivl_udfchar23'];
								   var vOrigInvPrice = rec.data['ivl_invqty'];
								   var vOrigInvQty = rec.data['ivl_price'];
								   
								  //if ((vOrderOrg===vOrg && vOrlEvent===vWO) || (vOrderOrg===vOrg && Ext.isEmpty(vOrlEvent))){
								   
								    var k = window.parentContext,
                                    f = window.EAM.Utils.getScreen(),
                                    i = (k && k.EAM) ? k.EAM : window.parent.EAM,
                                    m = i.Utils.getScreen(),
                                    j = m.getCurrentTab()
                                    if (j){
                                        console.log(j)
                                        var vFormPanel = j.getFormPanel();
                                        console.log(vFormPanel)
                                        vFormPanel.setFldValue('udfchar25', vOrigReceipt);
                                        vFormPanel.setFldValue('udfchar24', vOrigReceiptLine);
                                        vFormPanel.setFldValue('udfchar23', vOrigReceiptRef);
                                        /*if (vReturn == 'true'){
                                            vFormPanel.setFldValue('price', vOrigInvPrice);
                                            vFormPanel.setFldValue('qtyreturned', vOrigInvQty);
                                        }*/
                                    
                                        
                                        /*j.setFldValue('udfchar29', 'udfchar29');//sap invoice
                                        j.setFldValue('udfchar28', 'udfchar28');//sap invoice line
                                        j.setFldValue('udfchar25', 'udfchar25');//Receipt Number
                                        j.setFldValue('udfchar24', 'udfchar24');//Receipt line
                                        j.setFldValue('udfchar23', 'udfchar23');//Receipt Reference
                                        j.setFldValue('price', 1);//Receipt Reference*/
                                        //j.callParent();


                                    
                                    }
                                    vBtn.click();
                                    /*} else{
                                        EAM.Messaging.showError('Invalid PO and PO Line');
                                    }*/
                                    //EAM.getApplication().getController('base.external.ewsweb').externalReturnValueHyperlink();
							   })//itemdblclick
						
                                vGrid_Event_Bind = 1;
                            }
						 }//EAM.getApplication().isHyperlink
					 }catch (err){
						console.log(err);
					};
					 
				 }
				 
			}//tabname = LST
		
	    }; //return
	}, //get selector
	
	

});


function getURLVar(urlVarName) {
	var urlHalves = String(document.location).split('?');
	var urlVarValue = '';
	if(urlHalves[1]){var urlVars = urlHalves[1].split('&');for(i=0; i<=(urlVars.length); i++){if(urlVars[i]){var urlVarPair = urlVars[i].split('=');if (urlVarPair[0] && urlVarPair[0] == urlVarName) {urlVarValue = urlVarPair[1];}}}}
	return urlVarValue;
}
