#BIGDATA<-read.table("PCSI_0085_Ly_R_genome_coverage.txt",header=F)
#BIGDATA<-c("CHR","START","STOP","COV")
#COVG<-binData(BIGDATA)
#Uncomment above if working with unbinned data

BANDS<-read.table("cytobands/H.sapience/ideogram_9606_GCF_000001305",header=F,fill=T)
colnames(BANDS)<-c("CHR","ARM","CU","BEGIN","END","START","STOP","TYPE","DENS")

current=""
chroms<-as.character(unique(BANDS$CHR))
#Padding will determine the width of the gap b/w chromosomes on the plot
padding = 0.1 

sizes=c()
for(i in 1:length(chroms)) {
 sizes=rbind(sizes,c(NAME=chroms[i],SIZE=max(BANDS[BANDS$CHR==chroms[i],7])))
}


SIZES<-data.frame(sizes[,1],as.numeric(sizes[,2]),stringsAsFactors=FALSE)
colnames(SIZES)<-c("NAME","SIZE")
cradius = 100
x11res  = 72
colbands=rep("#FFFFFF",length(BANDS$DENS))

for(i in 1:length(BANDS$DENS)) {
shade=1

if(is.na(BANDS$DENS[i])){
 if(BANDS$TYPE[i]=="acen") {
  shade = 0.1
 }
 if(BANDS$TYPE[i]=="gvar"){
  shade = 0.84
 }
 if(BANDS$TYPE[i]=="stalk"){
  shade = 0.4
 }
}else{
 shade = (100-BANDS$DENS[i])/100
}
if(shade != 1){
 colbands[i] = rgb(shade,shade,shade)
}
}

BANDS<-cbind(BANDS,COL=colbands)

plot.new()
plot.window(ylim=c(-120,120),xlim=c(-120,120),asp=1)
draw.circle(0,0,cradius,lwd=1,border="gray")


totalbases=sum(SIZES$SIZE)
coeff=(totalbases+totalbases*padding)/360
gap_angle = totalbases*padding/length(SIZES$NAME)/coeff


current    = 0
covlimit   = 50
plothight  = 20
offset_sig = 15

# draw chromosomal boundaries with labels
for(i in 1:length(SIZES$NAME)){
ang<-SIZES$SIZE[i]/coeff
rad<-(pi*((current+ang/2+gap_angle/2)/180))
print(paste("Radian: ",rad))
radialtext(paste("Chr",as.character(SIZES$NAME[i],sep="")), center=c(0,0), start=cradius+2, angle=rad, expand=0, stretch=1, nice=TRUE, cex=1.1)
ang=ang+current+gap_angle
print(paste("Angle: ",ang))

#draw canvas for each group of bands
drawSectorAnnulus(round(pi*((current)/180),digits=2),round(pi*(ang/180),digits=2),cradius-9,cradius-1,"#73acb1",angleinc=0.01)
#draw canvas for each chromosome's density plot
drawSectorAnnulus(round(pi*((current+gap_angle/2)/180),digits=2),round(pi*((ang-gap_angle/2)/180),digits=2),cradius-plothight-(offset_sig+1),cradius-(offset_sig-1),"#cccccc",angleinc=0.01)

#draw ideogram for current sector
 for(j in 1:length(BANDS$START[BANDS$CHR==SIZES$NAME[i]])){
  ang1 = round(BANDS$START[BANDS$CHR==SIZES$NAME[i]][j]/coeff,digits=2)+gap_angle/2
  ang2 = round(BANDS$STOP[BANDS$CHR==SIZES$NAME[i]][j]/coeff,digits=2)+gap_angle/2
  if (ang1==ang2) {
    angsect = round(pi*((current+ang1)/180),digits=2)
    band_color = as.character(BANDS$COL[BANDS$CHR==SIZES$NAME[i]][j])
    drawSectorAnnulus(angsect,angsect,cradius-8,cradius-2,band_color,angleinc=0.01)
  } else {
    angsect1 = round(pi*((current+ang1)/180),digits=2)
    angsect2 = round(pi*((current+ang2)/180),digits=2)
    band_color = as.character(BANDS$COL[BANDS$CHR==SIZES$NAME[i]][j])
    drawSectorAnnulus(angsect1,angsect2,cradius-8,cradius-2,band_color,angleinc=0.01)
  }
 }
current<-ang
draw.radial.line(cradius-1,cradius+3,center=c(0,0),deg=ang,lwd=1.5,col="gray")
}


# Calculate approximated perimeter of our circle
perimeter = round(dev.size()[1]*x11res*pi)
base_per_pix = totalbases/perimeter


COVG<-read.table("test_mean",header=F)
colnames(COVG)<-c("CHR","START","STOP","COV")

current    = 0
covcoeff   = round(plothight/covlimit,digits=2)


# draw coverage density plot
for(i in 1:length(SIZES$NAME)){
 this_chrom<-COVG[COVG$CHR==SIZES$NAME[i],]
 print(paste("Chromosome ",i," size: ",length(this_chrom$COV)))  


 for(j in 1:length(this_chrom$CHR)){
  ang = this_chrom$START[j]/coeff+current+gap_angle/2
  
  height = covcoeff*this_chrom$COV[j]
  if (height > plothight) {
   draw.radial.line(cradius-plothight-offset_sig,cradius-offset_sig,center=c(0,0),deg=ang,lwd=1.5,col="blue")
  } else {
   draw.radial.line(cradius-plothight-offset_sig,cradius-plothight-offset_sig+height,center=c(0,0),deg=ang,lwd=1.5,col="blue")
  }
 }
 ang<-SIZES$SIZE[i]/coeff+gap_angle/2
 current=current+ang+gap_angle/2
  
}

png(filename="cyclogram.test.png",width = 1800, height = 1800, units = "px", pointsize = 24, bg = "white", antialias="default")

# ====================================================================================================================================
# Binner - currently handles coverage analysis results, needs to be modified to handle data from workflows other than CoverageAnalysis
# ====================================================================================================================================
binData<-function(x,binsize=100000,stat="mean",verbose=TRUE)
{
 if(!is.data.frame(x)) stop("Argument for binData must be a data frame")
 CN<-colnames(x)
 if (CN[1]!="CHR" || CN[2]!="START" || CN[3]!="STOP" || CN[4]!="COV") {
     print("Before binning coverage data make sure the column names are set properly")
     return(NA)
 }
 ndata=c()
 buffer=c()

 for (i in 1:length(x$CHR)) {
  if (current != x$CHR[i] || stop-start>=binsize) {
      if(length(buffer) > 0) {
         if (stat=="median") {
            ndata<-rbind(ndata,c(current,start,stop,ceiling(median(buffer))))
         } else {
            ndata<-rbind(ndata,c(current,start,stop,ceiling(mean(buffer))))
         }
      }
    start   = x$START[i]
    stop    = x$STOP[i]
    buffer  = c(x$COV[i])
    if (current!=x$CHR[i]) print(paste("Binning chromosome ",x$CHR[i]))
    current = as.character(x$CHR[i])
    } else {
    stop    = x$STOP[i]
    buffer  = c(buffer,x$COV[i])
  }
 }
 
 result<-data.frame(ndata[,1],as.numeric(ndata[,2]),as.numeric(ndata[,3]),as.numeric(ndata[,4]),stringsAsFactors=FALSE)
 colnames(result)<-c("CHR","START","STOP","COV")
 return(result)
}

