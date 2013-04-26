myDATA=list(I   = c("DATA_gei11", "DATA_lin11", "DATA_blmp1", "DATA_daf16"),
            II  = c("DATA_hlh1" , "DATA_egl27", "DATA_unc130"),
            III = c("DATA_nhr6", "DATA_dpy27", "DATA_lin39", "DATA_mab5", "DATA_egl5"),
            IV  = c("DATA_ama1", "DATA_eor1", "DATA_alr1", "DATA_pes1", "DATA_nhr105", "DATA_mep1"),
            V   = c("DATA_pha4"),
            X   = c("DATA_ceh14", "DATA_ceh30", "DATA_elt3", "DATA_hlh8", "DATA_unc130"))
myNAMES=list(DATA_gei11 = "GEI-11", DATA_lin11="LIN-11", DATA_blmp1="BLMP-1", DATA_daf16="DAF-16",
             DATA_hlh1  = "HLH-1", DATA_egl27 ="EGL-27", DATA_unc130="UNC-130", DATA_nhr6="NHR-6",
             DATA_dpy27 = "DPY-27", DATA_lin39 = "LIN-39", DATA_mab5 = "MAB-5", DATA_egl5 = "EGL-5",
             DATA_ama1 = "AMA-1", DATA_eor1 = "EOR-1", DATA_alr1 = "ALR-1", DATA_pes1 = "PES-1",
             DATA_nhr105 = "NHR-105", DATA_mep1 = "MEP-1", DATA_pha4 = "PHA-4", DATA_ceh14 = "CEH-14",
             DATA_ceh30 = "CEH-30", DATA_elt3 = "ELT-3", DATA_hlh8 = "HLH-8", DATA_unc130 = "UNC-130")
myCOL=list(I="salmon",II="green",III="orange",IV="lightgreen","V"="lightblue",X="wheat")

plotWORM = function (c) {
  
 par(mfrow=c(3,2),mar=c(10,3,2,3))
 
 for(gene in myDATA[[c]]) {
  message(cat("Plotting Gene ",gene))
  STAGES = list(N2EE=apply(get(gene)[,21:23],1,median),
                N2LE=apply(get(gene)[,24:26],1,median),
                L1=apply(get(gene)[,3:5],1,median),
                L2=apply(get(gene)[,6:8],1,median),
                L3=apply(get(gene)[,9:11],1,median),
                L4m=apply(get(gene)[,12:14],1,median),
                L4=apply(get(gene)[,15:17],1,median),
                L4s=apply(get(gene)[,18:20],1,median),
                YA=apply(get(gene)[,27:29],1,median),
                YA.gonad=apply(get(gene)[,30:32],1,median))
  boxplot(STAGES,
          col = myCOL[[c]],
          las = 3,
          main= myNAMES[[gene]])
  MED<-NULL
  for(stage in STAGES) {
   if(is.null(MED)){
    MED<-cbind(stage)
   }else{
    MED<-cbind(MED,stage)
   }
  }
  
  
  dm<-apply(MED,2,median)
  lines(1:10,dm,type="b",pch=4,cex=2.0,col="black")
 }
}


