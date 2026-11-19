package performance

import com.intuit.karate.gatling.PreDef._
import io.gatling.core.Predef._
import scala.concurrent.duration._

class EowynStressSimulation extends Simulation {

  val protocol = karateProtocol(
    "/api/auth/login" -> Nil,
    "/api/categories" -> Nil,
    "/api/books" -> Nil
  )

  protocol.nameResolver = (request, _) => request.getHeader("karate-name")

  val catalogScenario = scenario("Estrés: login y consultas de catálogo")
    .exec(karateFeature("classpath:features/catalog.feature"))
    .pause(12.seconds)

  setUp(
    catalogScenario.inject(
      rampConcurrentUsers(0).to(25).during(10.seconds),
      constantConcurrentUsers(25).during(15.seconds),
      rampConcurrentUsers(25).to(50).during(10.seconds),
      constantConcurrentUsers(50).during(15.seconds),
      rampConcurrentUsers(50).to(75).during(10.seconds),
      constantConcurrentUsers(75).during(15.seconds),
      rampConcurrentUsers(75).to(100).during(10.seconds),
      constantConcurrentUsers(100).during(15.seconds),
      rampConcurrentUsers(100).to(125).during(10.seconds),
      constantConcurrentUsers(125).during(15.seconds)
    ).protocols(protocol)
  )
}
