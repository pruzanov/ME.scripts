# Parameters we should be receiving from outside as arguments
VARIANT = 1  # VARIANT 1 = percent target covered 2 = numeric coverage

# For png size, aim for 1480x470 for single panel, 33px per sample in heatmap
# Proportions 14 x 6.5 seem to work well

# Parameters which will determine the proportions and other sizing
# iSTART and iEND should be set in an array
POINTS = 700 # number of features to plot in one panel
iSTART = 1
iEND   = POINTS  # Will be used to draw separate panels, START and END are indexes of target features used to draw the plots

# Loading test data
BARDATA<-read.table("readstats.test2.txt",header=F)
CGDATA<-read.table("halt_coding.cg",header=F)
colnames(CGDATA)=c("CG")

COVDATA<-read.table("average.target_coverage.txt",header=T)
PERDATA<-read.table("percent.target_coverage.txt",header=T)
SAMPLES = length(PERDATA[1,])-3

TABDATA<-as.data.frame(sapply(PERDATA[,4:(SAMPLES+3)],mean)) 
colnames(TABDATA)=c("Coverage")


# Calculate chromosome boundaries, in indexes for target features
bounds=c(1)
chr=COVDATA$Chrom[1]
chroms=c(as.character(chr))

for(i in 1:length(COVDATA[,1])) {
 if(chr!=COVDATA$Chrom[i]){
  bounds=c(bounds,i)
  chroms=c(chroms,as.character(COVDATA$Chrom[i]))
  chr=COVDATA$Chrom[i]
 }
}

chromBounds = data.frame(chroms,bounds)

# Bring the data into range
normCOVDATA<-sapply(COVDATA[,4:(SAMPLES+3)],function(x){x/diff(range(COVDATA[,4:(SAMPLES+3)]))},USE.NAMES=T)
normPERDATA<-sapply(PERDATA[,4:(SAMPLES+3)],function(x){x/diff(range(PERDATA[,4:(SAMPLES+3)]))},USE.NAMES=T)



# Function for drawing colorstrips
colorstrip<-function(cls,base,height,margin=0) {
 print(paste("Calling colorstrip for ",length(cls)," colors for base ",base," height ",height))
 for(c in 1:length(cls)){
  #lines(c(c,c),c(base,base+height-margin), col=cls[c], lty='solid')
  rect(c, base+margin, c+1, base+height-margin, border=NA, col=cls[c], lty="solid")
 }
}

# Layout for the figure (1 of n if n of points > limit):

nf <- layout(matrix(c(5,0,6,
                      0,0,3,
                      1,4,2),nc=3,byrow=T),
       height=c(0.5,lcm(2),4),
       width =c(1.5,lcm(2),5))
layout.show(nf)

# Debugging
#box(which="outer",lty="dotted")

# Plotting:

# Barcode plot:
LANE  = "Test"
TITLE = paste("Multiplexing Representation for ",LANE,sep="")
COLOR = "cadetblue"
CGFUN <- colorRamp(c("white","blue"),space="rgb")
if (VARIANT == 1) {
FUN <- colorRamp(c("white","blue"),space="rgb")
} else {
FUN <- colorRamp(c("white","red"),space="rgb")
}



# Barcode representation Plot, note that we are reversing the table so that samples go from top to bottom
par(mar=c(4,7,2,1)+0.1,xpd=F)
barplot(rev(BARDATA[,2]),width<-c(1,1,1),space=0.3,names=rev(BARDATA[,1]),col=COLOR,xlab="% of Ideal representation", cex=0.82, cex.axis=1.3, cex.lab=1.3, las=2, xlim=c(0,max(BARDATA[,2])+10),horiz=T)  # Need to determine the best range
abline(v=100, lty="dotted")
mtext("Barcode ID", cex=0.6, side=3, adj=-0.4)
# main=TITLE,

# Heatmap plot:
par(mar=c(4,0,2,0)+0.1)

if (VARIANT == 1) {
cols<-rgb(FUN(normPERDATA[iSTART:iEND,]),maxColorValue=255)
} else {
cols<-rgb(FUN(normCOVDATA[iSTART:iEND,]),maxColorValue=255)
}


plot(1, type="n", axes=F, xlab="", ylab="",xlim=c(0,POINTS),ylim=c(0,SAMPLES*10),yaxs = 'i',xaxs = 'i')
POINTS=length(cols)/SAMPLES
for(s in 1:SAMPLES) {
 index = SAMPLES - s + 1
 colorstrip(cols[(1+POINTS*(s-1)):(POINTS*s)],(index-1)*10,10,1)  
}
POINTS=700

# Side bar (horizontal) CG content
par(mar=c(1,0,2,0)+0.1)
normCG<-with(CGDATA,(CG - min(CG)) / diff(range(CG)))
# Need to make a slice of normCG
sliceCG<-normCG[iSTART:iEND];
#sliceCG<-normCG[701:1400];
#sliceCG<-normCG[1401:2037];

cols<-rgb(CGFUN(sliceCG),maxColorValue=255)
#abline(v=POINTS,col="black")
# Set up the ticks for chromosomes using global iSTART and iEND indexes
tickSlice=c(1)
# Assume that chromosomes and bounds' indexes are sorted
tickLabs=NULL

for(t in 1:length(chromBounds$chroms)) {
  if (chromBounds$bounds[t] <= iSTART) {
    tickLabs=c(as.character(chromBounds$chroms[t]))
  }
  if (chromBounds$bounds[t] > iSTART && chromBounds$bounds[t] < iEND) {
    tickSlice=c(tickSlice, chromBounds$bounds[t] - iSTART)
    tickLabs=c(tickLabs, as.character(chromBounds$chroms[t]))
  }
}


barplot(rep(10,length(cols)),col=cols,border=NA,space=0,axes=F,xlab="",ylab="",xlim=c(0,POINTS),ylim=c(0,10),yaxs = 'i',xaxs = 'i')
axis(1,at=tickSlice,line=0,tick=T,font=2,labels=tickLabs,hadj=-0.2,lwd=0,lwd.tick=1,padj=-1)

mtext("CG%", cex=0.7, side=2, line=1, adj=0.5, font=2)


# Side bar (vertical) % Bases covered with text inside
par(mar=c(4,1,2,1)+0.1)
tabcols<-rgb(CGFUN(TABDATA$Coverage),maxColorValue=255)
plot.new()
plot.window(xlim=c(0,10),ylim=c(0,length(tabcols)), yaxs = 'i', xaxs = 'i' )
for(t in 1:length(tabcols)){
 index = length(tabcols) - t + 1
 aver = round(TABDATA$Coverage[index]*100, digits=0)
 
 rect(0, t-1, 10, t+9, border="white", lwd=2, col=tabcols[index], lty="solid")
 text(1.5,(t-1)+.5,aver,pos=4,font=2,cex=1.1,col=ifelse(aver > 40, "white", "black"))
}

#abline(v=0,lty='solid')
#abline(v=10,lty='solid')
#abline(h=0,lty='solid')
#abline(h=length(tabcols),lty='solid')


mtext("Coverage%", cex=0.7, side=3, line=1, adj=0.5, font=2)

# Title for Barcode representation
par(mar=c(0,1,1,1)+0.1)
plot.new()
plot.window(xlim=c(0,1),ylim=c(0,1), xaxs = 'i' )
text(.5, .25, "Barcode Representation", cex=1.6, font=2, adj=0.5, pos=3)

# Title for Heatmap area
par(mar=c(0,0,1,0)+0.1)
plot.new()
plot.window(xlim=c(0,1),ylim=c(0,1), xaxs = 'i')

if (VARIANT == 1) {
text(.5, .25, "Percent of Target Covered", cex=1.6, font=2, adj=0.5, pos=3)
} else {
text(.5, .25, "Average Target Coverage", cex=1.6, font=2, adj=0.5, pos=3)
}



# Legend colorstrip, for CG content and average % bases covered
legend<-seq(from=0,to=1,by=0.05)
legCOLs<-rgb(CGFUN(legend),maxColorValue=255)

lcof=.09/length(legCOLs)
for(c in 1:(length(legCOLs)-1)){
    rect(.9+(c-1)*lcof, .4, .9+(c-1)*lcof+.01, 1, border=NA, col=legCOLs[c], lty="solid")
}
rect(.9, .4, .99, 1, lty="solid")
text(.9, .1, "0", cex=0.9, adj = 1, pos=4)
text(1, .1, "100%", cex=0.9, adj=0, pos=2)

# Optional legend colorstrip for average Coverage (xN)
if (VARIANT==2) {
 legCOLs<-rgb(FUN(legend),maxColorValue=255)
 for(c in 1:(length(legCOLs)-1)){
    rect(.01+(c-1)*lcof, .4, .01+(c-1)*lcof+.01, 1, border=NA, col=legCOLs[c], lty="solid")
 }
 rect(.01, .4, .101, 1, lty="solid")
 text(0, .1, paste("x",min(COVDATA[,4:(SAMPLES+3)])), cex=0.9, adj = 1, pos=4)
 text(0.11, .1, paste("x",max(COVDATA[,4:(SAMPLES+3)])), cex=0.9, adj=0, pos=2)
}



# Image painting commands that should be used:
png(filename="Test.png",width=1400,height=640,units="px",pointsize=15,type="cairo-png",antialias="default")
