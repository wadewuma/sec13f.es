#' Descarga y devuelve el contenido de los formularios de un archivo indice o solo los descarga, a eleccion del usuario
#'
#' \link[sec13f.es]{recorreFormularios} Recorre los formularios de la SEC contenidos en la coleccion que se pasa como input
#' y almacena la informacion en dos colecciones de documentos de mongo. Una para la tabla de inversiones y otra para el
#' resto de informacion del formulario 13f. Utiliza \link[sec13f.es]{extraeDatos} para extraer la informacion de cada
#' formulario.
#'
#' @param nombreBD nombre de la base de datos de mongo que contiene el indice de los formularios a recorrer
#' @param mongoURL parametro de la url necesaria para concectar con mongo
#' @param tiempoLim tiempo limite en segundos para extraer los datos de un formulario. 5 minutos por defecto.
#'
#' @return devuelve el dataframe con el listado de los formularios registrados en ese o esos periodos.
#'   lo descarga de \url{https://www.sec.gov/Archives/edgar/full-index/}
#'   Tambien devuelve el estado de la descarga y el numero de formularios e inversores recibidos en ese/esos
#'   periodos.
#'
#' @examples
#' \dontrun{
#' recorreFormularios( nombreBD = paste0(format(Sys.Date(),'%Y%m%d'), 'sec13f'),
#'                     mongoURL = 'mongodb://localhost:27017')
#'}
#'
#'@import mongolite
#'@import stringr
#'@import R.utils
#'@import dplyr
#'
#'@export
recorreFormularios <- function( nombreBD = paste0( format(Sys.Date(), "%Y%m%d"), "sec13f"),
                                mongoURL = "mongodb://localhost:27017", tiempoLim = 60 * 5) {
    
    inicio <- Sys.time()  # se usa para calcular el tiempo medio
    # options(warn = -1) # remove warnings
    limpiaMaster <- function(nombreBD, mongoURL) {
        
        # options(warn = -1) # remove warnings library(mongolite)
        conexion <- mongolite::mongo(collection = "indice", db = nombreBD, url = mongoURL)
        master <- conexion$find()
        conexion <- mongolite::mongo(collection = "header", db = nombreBD, url = mongoURL)
        mongoMaster <- conexion$find(query = "{}", fields = "{\"accessionNumber\" : true, \"_id\": false}"  #query = '{}', fields = '{'accessionNumber' : true, '_id': true}'
        )
        
        # necesito quedarme con las id que son los accession numbers library('dplyr') library('stringr')
        masterLimpio <- master[!(stringr::str_sub(master$edgarLink, -24, -5) %in% mongoMaster$accessionNumber), ]
        return(masterLimpio)
    }
    
    master <- limpiaMaster(nombreBD = nombreBD, mongoURL = mongoURL)
    master <- master[order(master$dateFiled, decreasing = T), ] # para que empiece por los ultimos
    
    if (nrow(master) > 0) {
        
        totalForms <- nrow(master)
        print(paste0("Formularios a cargar: ", totalForms))

        for (i in 1:totalForms) {
            link <- paste0("https://www.sec.gov/Archives/", master$edgarLink[i])
            # print(paste0('Dentro extraeDatos() a las : ', format(Sys.time(), '%H:%M:%S')))
            superaTiempo <- 0
            datos <- NULL
            tryCatch({
                datos <- R.utils::withTimeout({
                  extraeDatos(link)
                }, timeout = tiempoLim)
            }, TimeoutException = function(ex) {
                message(paste0(stringr::str_sub(master$edgarLink[i], -24, -5), " Timeout. Salta el formulario."))
            })

            if (is.null(datos)) {
                superaTiempo <- 1
                nfil <- 0
            } else { 
                if (is.null(datos[[1]]$tableEntryTotal2)) {
                        nfil <- 0
                } else {
                        nfil <- datos[[1]]$tableEntryTotal2
                        }
                }
            
            tmedio <- as.character(round(difftime(Sys.time(), inicio, units = "secs")/i, digits = 2))  # tiempo medio de computacion en segundos - descarga y carga en json
            tempStatus <- data.frame( nform = i, 
                                      totalForms = totalForms, 
                                      accessionNumber = stringr::str_sub(master$edgarLink[i], -24, -5), 
                                      horaInicio = format(inicio, "%H:%M:%S"),
                                      horaCarga = format(Sys.time(), "%H:%M:%S"), 
                                      tiempoMedio = tmedio, 
                                      excedeTiempo = superaTiempo, 
                                      nfilas = nfil)
            print(tempStatus)
            conexion <- mongo(collection = "registro", db = nombreBD, url = mongoURL)
            conexion$insert(tempStatus)
            ## vamos con mongoDB ################################################################################################ inicio
            ## una conexion en mongoDB ###########################################################################################3
            if (superaTiempo == 0) {
                conexion <- mongo(collection = "header", db = nombreBD, url = mongoURL)
                conexion$insert(datos[[1]])
                # condicion anterior: !is.na(datos[[2]][1, 1])
                if (!is.null(datos[[2]])) {
                    if (!is.na(datos[[2]][1, 1])) {
                      conexion <- mongo(collection = paste0("holdings", datos[[1]]$period), db = nombreBD, url = mongoURL)
                      conexion$insert(datos[[2]])
                    }
                }
            }
        }  # loop 
        conexion <- mongo(collection = "registro", db = nombreBD, url = mongoURL)
        registro <- conexion$find()
        return(registro)
    }
}
