% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/extraeDatos.R
\name{extraeDatos}
\alias{extraeDatos}
\title{Extrae informacion del archivo .txt que proporciona EDGAR (SEC).}
\usage{
extraeDatos(linkArchivo)
}
\arguments{
\item{linkArchivo}{una direccion a un archivo de texto desde el directorio de trabajo.}
}
\value{
devuelve una lista con 3 elementos, el primero es la parte descriptiva del formulario;
el segundo es la tabla de inversiones; y el tercero el numero de filas que tiene la tabla de inversiones
}
\description{
Extrae informacion del archivo .txt que proporciona EDGAR (SEC).
}
\examples{
\dontrun{
linkArchivo <- paste0("https://www.sec.gov/Archives/edgar/data/",
              "1167557/000108514619000779/0001085146-19-000779.txt")

extraeDatos(linkArchivo)

## No es necesario utilizar paste0, aqui se ha usado porque, si no,
## la documentacion de R lo corta y no se ve la direccion completa.
}

}
