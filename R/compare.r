panel.draw <- function(exp)
{
pairs(exp, lower.panel=NULL, upper.panel=panel.cor)
}

panel.cor <- function(x, y, digits=2, prefix="", cex.cor)
{
    usr <- par("usr"); on.exit(par(usr))
    par(usr = c(0, 1, 0, 1))
    r <- abs(cor(x, y))
    txt <- format(c(r, 0.123456789), digits=digits)[1]
    txt <- paste(prefix, txt, sep="")
    if(missing(cex.cor)) cex <- 0.6/strwidth(txt)
    
    test <- cor.test(x,y)

    # borrowed from printCoefmat (although with errors, fixed)
    Signif <- symnum(test$estimate, corr = FALSE, na = FALSE,
                  cutpoints = c(0, 0.01, 0.1, 0.4, 0.75, 1),
                  symbols = c(" ", ".", "*", "**", "***" ))
    
    text(0.5, 0.5, txt, cex = cex*r)
    text(.8, .8, Signif, cex = cex, col=2)
}

table.draw <- function (exp)
{   
    table = NULL #matrix(nrow=nrow(exp),ncol=ncol(exp))
    for(i in 2:ncol(exp)) 
    {
       coeff = NULL
       for(j in i:ncol(exp))
       {
         test = cor.test(exp[,i-1],exp[,j])
         coeff = c(coeff,as.numeric(sprintf("%.2f",test$estimate)))
       }
       table<-rbind(table,c(rep(0,i-2),1.00,coeff))
    }
    table<-rbind(table,c(rep(0,ncol(exp)-1),1.00))

    colnames(table) = colnames(exp)
    rownames(table) = colnames(exp)

    for(i in 2:nrow(table)){
     for(j in 1:(i-1)){
      table[i,j] = table[j,i]
     }
    }


    table
}

