# Author: Robert J. Hijmans
# Date :  June 2008
# Version 0.9
# Licence GPL v3



setMethod("plot", signature(x='Raster', y='Raster'), 
	function(x, y, maxpixels=100000, cex, xlab, ylab, nc, nr, maxnl=16, main, add=FALSE, gridded=FALSE, ncol=25, nrow=25, ...) {
	
		compareRaster(c(x, y), extent=TRUE, rowcol=TRUE, crs=FALSE, stopiffalse=TRUE) 
		nlx <- nlayers(x)
		nly <- nlayers(y)

		maxnl <- max(1, round(maxnl))
		nl <- max(nlx, nly)
		if (nl > maxnl) {
			nl <- maxnl
			if (nlx > maxnl) {
				x <- x[[1:maxnl]]
				nlx <- maxnl
			}
			if (nly > maxnl) {
				y <- y[[1:maxnl]]
				nly <- maxnl
			}
		}
		
		
		if (missing(main)) {
			main <- ''
		}
		
		if (missing(xlab)) {
			ln1 <- names(x)
		} else {
			ln1 <- xlab
			if (length(ln1) == 1) {
				ln1 <- rep(ln1, nlx)
			}
		}
		if (missing(ylab)) {
			ln2 <- names(y)
		} else {
			ln2 <- ylab
			if (length(ln1) == 1) {
				ln2 <- rep(ln2, nly)
			}
		}

		cells <- ncell(x)
		
		# gdal selects a slightly different set of cells than raster does for other formats.
		# using gdal directly to subsample is faster.
		
		if (gridded) {
			if ((ncell(x) * (nlx + nly)) < .maxmemory()) {
				maxpixels <- ncell(x)
			}
		}
		
		dx <- .driver(x, warn=FALSE)
		dy <- .driver(y, warn=FALSE)
		if ( all(dx =='gdal') & all(dy == 'gdal')) {
			x <- sampleRegular(x, size=maxpixels, useGDAL=TRUE) 
			y <- sampleRegular(y, size=maxpixels, useGDAL=TRUE)
		} else {
			x <- sampleRegular(x, size=maxpixels)
			y <- sampleRegular(y, size=maxpixels)
		}
		if (NROW(x) < cells) {
			warning(paste('plot used a sample of ', round(100*NROW(x)/cells, 1), '% of the cells. You can use "maxpixels" to increase the sample)', sep=""))
		}

		if (missing(cex)) {
			if (NROW(x) < 100) {
				cex <- 1
			} else if (NROW(x) < 1000) {
				cex <- 0.5
			} else {
				cex <- 0.2
			}
		}


		
		if (nlx != nly) {	
			# recycling
			d <- cbind(as.vector(x), as.vector(y))
			x <- matrix(d[,1], ncol=nl)
			y <- matrix(d[,2], ncol=nl)
			lab <- vector(length=nl)
			lab[] <- ln1
			ln1 <- lab
			lab[] <- ln2
			ln2 <- lab		
		}
		
		if (nl > 1) {
			if (missing(nc)) {
				nc <- ceiling(sqrt(nl))
			} else {
				nc <- max(1, min(nl, round(nc)))
			}
			if (missing(nr)) {
				nr <- ceiling(nl / nc)
			} else {
				nr <- max(1, min(nl, round(nr)))
				nc <- ceiling(nl / nr)
			}
			
			old.par <- graphics::par(no.readonly = TRUE) 
			on.exit(graphics::par(old.par))
			graphics::par(mfrow=c(nr, nc), mar=c(4, 4, 2, 2))
			
			
			if (! gridded) {
				if (add) {
					for (i in 1:nl) {
						points(x[,i], y[,i], cex=cex, ...)			
					}				
				} else {
					for (i in 1:nl) {
						plot(x[,i], y[,i], cex=cex, xlab=ln1[i], ylab=ln2[i], main=main[i],  ...)			
					}
				}
			} else {
				for (i in 1:nl) {
					.plotdens(x[,i], y[,i], nc=ncol, nr=nrow, main=main[i], xlab=ln1[i], ylab=ln2[i], add=add, ...)		
				}
			}
		} else  {
			if (! gridded) {
				if (add) {
					points(x, y, cex=cex, ...)
				} else {
					plot(x, y, cex=cex, xlab=ln1[1], ylab=ln2[1], main=main[1], ...)			
				}
			} else {
				.plotdens(x, y, nc=ncol, nr=nrow, main=main[1], xlab=ln1[1], ylab=ln2[1], ...)
			}
		}		
	}
)


.plotdens <- function(x, y, nc, nr, asp=NULL, xlim=NULL, ylim=NULL, ...) {
	xy <- stats::na.omit(cbind(x,y))
	if (nrow(xy) == 0) {
		stop('only NA values (in this sample?)')
	}
	r <- apply(xy, 2, range)
	rx <- r[,1]
	if (rx[1] == rx[2]) {
		rx[1] <- rx[1] - 0.5
		rx[2] <- rx[2] + 0.5
	}
	ry <- r[,2]
	if (ry[1] == ry[2]) {
		ry[1] <- ry[1] - 0.5
		ry[2] <- ry[2] + 0.5
	}
	
	out <- raster(xmn=rx[1], xmx=rx[2], ymn=ry[1], ymx=ry[2], ncol=nc, nrow=nr)
	out <- rasterize(xy, out, fun=function(x, ...) length(x), background=0)
	if (!is.null(xlim) | !is.null(ylim)) {
		if (is.null(xlim)) xlim <- c(xmin(x), xmax(x))
		if (is.null(ylim)) ylim <- c(ymin(x), ymax(x))
		e <- extent(xlim, ylim)
		out <- extend(crop(out, e), e, value=0)
	}
	.plotraster2(out, maxpixels=nc*nr, asp=asp, ...) 	
}


