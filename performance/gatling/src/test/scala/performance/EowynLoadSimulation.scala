package performance

import io.gatling.core.Predef._
import io.gatling.http.Predef._
import scala.concurrent.duration._

class EowynLoadSimulation extends Simulation {

  val baseUrl = Option(System.getenv("BASE_URL")).getOrElse("http://localhost:3000")
  val email = Option(System.getenv("TEST_EMAIL")).getOrElse(throw new IllegalArgumentException("Define TEST_EMAIL"))
  val password = Option(System.getenv("TEST_PASSWORD")).getOrElse(throw new IllegalArgumentException("Define TEST_PASSWORD"))
  val httpProtocol = http.baseUrl(baseUrl).acceptHeader("application/json")

  // Gatling HTTP genera la carga; el smoke Karate separado valida el mismo flujo funcional.
  val catalogScenario = scenario("Carga: login y consultas de catálogo")
    .exec(
      http("POST /api/auth/login")
        .post("/api/auth/login")
        .formParam("email", email)
        .formParam("password", password)
        .check(status.is(200), jsonPath("$.token").saveAs("jwt"))
    )
    .exitHereIfFailed
    .exec(
      http("GET /api/categories")
        .get("/api/categories?page=1&limit=50")
        .header("Authorization", "Bearer #{jwt}")
        .check(status.is(200), jsonPath("$.categories").exists)
    )
    .exec(
      http("GET /api/books")
        .get("/api/books?page=1&limit=30")
        .header("Authorization", "Bearer #{jwt}")
        .check(status.is(200), jsonPath("$.books").exists)
    )
    .pause(5.seconds)

  val targetRate = 20.0
  setUp(
    catalogScenario.inject(
      rampUsersPerSec(0).to(targetRate).during(30.seconds),
      constantUsersPerSec(targetRate).during(60.seconds)
    ).protocols(httpProtocol)
  )
}
