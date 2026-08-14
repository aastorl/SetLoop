import Foundation

extension Error {
    var setLoopUserMessage: String {
        if let apiError = self as? APIError {
            return apiError.userFacingMessage
        }

        if let authError = self as? AuthServiceError {
            return authError.userFacingMessage
        }

        if let urlError = self as? URLError {
            return urlError.userFacingMessage
        }

        let description = localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard description.isEmpty == false else {
            return "No se pudo completar la operacion. Intentalo de nuevo."
        }

        if description.contains("NSURLErrorDomain")
            || description.contains("The operation couldn")
            || description.contains("{\"") {
            return "No se pudo completar la operacion. Intentalo de nuevo."
        }

        return description
    }
}

private extension APIError {
    var userFacingMessage: String {
        switch self {
        case .missingSupabaseConfiguration:
            return "Falta la configuracion de Supabase para conectar con el servidor."
        case .invalidURL:
            return "La configuracion de Supabase no es valida."
        case .emptyResponse:
            return "El servidor no devolvio datos. Refresca la pantalla e intentalo de nuevo."
        case .decodingFailed:
            return "No se pudo leer la respuesta del servidor. Refresca la pantalla e intentalo de nuevo."
        case .requestFailed(let statusCode, let message):
            if message.contains("delete_historical_application") {
                return "Falta aplicar la migracion de borrado historico en Supabase antes de eliminar candidaturas pasadas."
            }

            if message.contains("venue_place_name")
                || message.contains("venue_latitude")
                || message.contains("venue_longitude") {
                return "Falta aplicar la migracion de ubicacion en Supabase antes de guardar direcciones."
            }

            switch statusCode {
            case 400, 422:
                return "No se pudo guardar el cambio. Revisa los datos e intentalo de nuevo."
            case 401, 403:
                return "Tu sesion no tiene permisos para esta accion. Inicia sesion de nuevo si el problema continua."
            case 404:
                return "No encontramos esos datos en el servidor. Refresca la pantalla e intentalo de nuevo."
            case 409:
                return "Este cambio entra en conflicto con datos ya guardados. Refresca la pantalla e intentalo de nuevo."
            case 500..<600:
                return "Supabase no pudo completar la operacion ahora mismo. Intentalo de nuevo en unos minutos."
            default:
                return "No se pudo completar la operacion. Codigo \(statusCode)."
            }
        case .keychain:
            return "No se pudo acceder a la sesion guardada. Inicia sesion de nuevo."
        }
    }
}

private extension AuthServiceError {
    var userFacingMessage: String {
        switch self {
        case .emailConfirmationRequired:
            return "Cuenta creada. Confirma tu email y despues inicia sesion."
        case .missingSession:
            return "Tu sesion ha caducado. Inicia sesion de nuevo."
        case .profileMissing:
            return "No encontramos el perfil de esta cuenta. Inicia sesion de nuevo si el problema continua."
        case .profileSessionMismatch:
            return "El perfil no pertenece a la sesion activa. Inicia sesion de nuevo."
        }
    }
}

private extension URLError {
    var userFacingMessage: String {
        switch code {
        case .notConnectedToInternet:
            return "No hay conexion a internet. Revisa la conexion e intentalo de nuevo."
        case .networkConnectionLost:
            return "Se perdio la conexion durante la operacion. Intentalo de nuevo."
        case .timedOut:
            return "La conexion ha tardado demasiado. Intentalo de nuevo."
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "No se pudo conectar con Supabase. Revisa la conexion e intentalo de nuevo."
        case .cancelled:
            return "La operacion se cancelo antes de terminar."
        default:
            return "No se pudo conectar con el servidor. Intentalo de nuevo."
        }
    }
}
