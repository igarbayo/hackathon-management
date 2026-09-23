# Resuelve de quién es la clave de Gemini que se usa en cada llamada a la IA
# (06-analisis-ia.md#proveedor, RF-AI-021). Las acciones que dispara una
# persona (análisis manual, MCP) usan su propia clave; lo automático (el
# cron de análisis programado y la sugerencia de atribución) no tiene un
# actor, así que usa la del owner del equipo. Si nadie la tiene puesta, la
# llamada no se hace: no hay una clave compartida del servidor de reserva.
module Ai
  module KeyOwner
    module_function

    def for(team)
      Membership.owners.where(team_id: team.id).first&.user
    end
  end
end
