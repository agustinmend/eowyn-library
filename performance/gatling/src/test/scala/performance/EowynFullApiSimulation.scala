package performance

import com.intuit.karate.gatling.PreDef._
import io.gatling.core.Predef._

class EowynFullApiSimulation extends Simulation {

  private val enabled = Option(System.getenv("ENABLE_WRITE_TESTS")).contains("true")
  require(
    enabled,
    "Esta simulacion registra usuarios y escribe datos. Define ENABLE_WRITE_TESTS=true solo contra una base local/disposable."
  )

  private val users = Option(System.getenv("WRITE_TEST_USERS")).map(_.toInt).getOrElse(1)
  require(users >= 1 && users <= 20, "WRITE_TEST_USERS debe estar entre 1 y 20 para limitar la escritura de fixtures.")

  val protocol = karateProtocol(
    "/api/auth/register" -> Nil,
    "/api/auth/login" -> Nil,
    "/api/auth/validate-email/{token}" -> Nil,
    "/api/categories" -> Nil,
    "/api/categories/{id}" -> Nil,
    "/api/books" -> Nil,
    "/api/books/{id}" -> Nil,
    "/api/loans" -> Nil,
    "/api/loans/{id}/return" -> Nil
  )

  protocol.nameResolver = (request, _) => request.getHeader("karate-name")

  val fullApiLifecycle = scenario("Cobertura API completa con fixtures aislados")
    .exec(karateFeature("classpath:features/full-api-lifecycle.feature"))

  // Una iteración por usuario: registra un usuario y crea/retira sus fixtures.
  // La limpieza de la base local se documenta en scripts/cleanup-gatling-fixtures.sql.
  setUp(
    fullApiLifecycle.inject(atOnceUsers(users)).protocols(protocol)
  )
}
