# Simple script for plotting data from tiling arrays along a chromosome
alongChromTicks = function(x){
  rx = range(x)
  lz = log((rx[2]-rx[1])/3, 10)
  fl = floor(lz)
  if( lz-fl > log(5, 10))
    fl = fl +  log(5, 10)
  tw = round(10^fl)
  i0 = ceiling(rx[1]/tw)
  i1 = floor(rx[2]/tw)
  seq(i0, i1)*tw
}

plotGeneData = function (data,Rep=1,gff_file,main="Tiling Array Normalized Signal",what=c("dots")) {
## Load data, gff
gff  = read.table(gff_file, header=TRUE)
Chrom = as.character(data$CHR[1])
strand = as.character(gff$strand[1])

Rep = Rep+2

dat  = list(x=data[,1],y=data[,Rep],flag=rep(0,length(data[,3])))
xlim = c(min(data$START),max(data$START))
ylim = c(min(dat$y),max(dat$y))
ylab = colnames(dat$y)

grid.newpage()

VP = c("title"=1.5, "expr"=4, "gff"=2, "coord"=1, "legend"=0.4)
pushViewport(viewport(width=0.85, height=0.95)) ## plot margins
pushViewport(viewport(layout=grid.layout(length(VP), 1, height=VP)))

plotSegmentationDots(dat, xlim, ylim, threshold=NA, strand=strand, chr=Chrom, main=main, what=what, showConfidenceIntervals=FALSE, vpr=which(names(VP)=="expr"), sepPlots=FALSE)
plotFeatures(gff=gff,chr=Chrom,strand=strand,xlim=xlim,vpr=which(names(VP)=="gff"))

coord=as.vector(data$START)

## chromosomal coordinates
pushViewport(dataViewport(xData=coord, yscale=c(-0.4,0.8), extension=0, layout.pos.col=1, layout.pos.row=which(names(VP)=="coord")))
grid.lines(coord, c(0,0), default.units = "native")
tck = alongChromTicks(coord)
grid.text(label=formatC(tck, format="d"), x = tck, y = 0.2, just = c("centre", "bottom"), gp = gpar(cex=.6), default.units = "native")
grid.segments(x0 = tck, x1 = tck, y0 = -0.17, y1 = 0.17,  default.units = "native")


## title
pushViewport(viewport(layout.pos.col=1, layout.pos.row=which(names(VP)=="title")))
grid.text(label=paste("Chr ", Chrom, sep=""), x=0.5, y=0.8, just="centre", gp=gpar(cex=0.9))
if(!missing(main))
  grid.text(label=main, x=0.05, y=1, just="centre", gp=gpar(cex=1))


}
