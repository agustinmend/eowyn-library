package performance

import com.intuit.karate.gatling.PreDef._
import io.gatling.core.Predef._
import scala.concurrent.duration._

class EowynCatalogSimulation extends Simulation {

  val protocol = karateProtocol(
    "/api/auth/login" -> Nil,
    "/api/categories" -> Nil,
    "/api/books" -> Nil
  )

  protocol.nameResolver = (request, _) => request.getHeader("karate-name")

  val catalogScenario = scenario("Login y consulta de catálogo")
    .exec(karateFeature("classpath:features/catalog.feature"))

  // Perfil provisional de humo/carga baja. Ajustar tras validar el entorno y acordar el alcance.
  setUp(
    catalogScenario.inject(
      rampUsers(2) during (10.seconds),
      constantUsersPerSec(1) during (20.seconds)
    ).protocols(protocol)
  )
}
