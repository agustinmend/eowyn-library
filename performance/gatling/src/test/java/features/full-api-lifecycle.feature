Feature: Cobertura de ciclo de vida para las APIs de Eowyn Library

  Background:
    * url baseUrl
    * def runId = java.util.UUID.randomUUID().toString().replace('-', '')
    * def email = 'gatling-e2e-' + runId + '@example.com'
    * def categoryName = 'Gatling ' + runId
    * def categoryDescription = 'Categoría de prueba Gatling ' + runId
    * def isbn = 'GAT-' + runId
    * def dueDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().substring(0, 10)

  Scenario: Ejecutar las APIs de auth, categorías, libros y préstamos con datos aislados
    # Registro crea un usuario persistente; su correo lleva prefijo exclusivo para limpieza posterior.
    Given path 'api', 'auth', 'register'
    And header karate-name = 'POST /api/auth/register'
    And form field name = 'Gatling E2E'
    And form field email = email
    And form field password = 'Gatling-123456'
    When method post
    Then status 200
    And match response.user.email == email
    And match response.user.id == '#number'
    * def testUserId = response.user.id

    Given path 'api', 'auth', 'login'
    And header karate-name = 'POST /api/auth/login'
    And form field email = email
    And form field password = 'Gatling-123456'
    When method post
    Then status 200
    And match response.token == '#string'
    * def accessToken = response.token

    Given path 'api', 'auth', 'validate-email', 'GATLING-' + runId
    And header karate-name = 'GET /api/auth/validate-email/:token'
    When method get
    Then status 200
    And match response.message == 'validateEmail'

    Given path 'api', 'categories'
    And header Authorization = 'Bearer ' + accessToken
    And header karate-name = 'POST /api/categories'
    And form field name = categoryName
    And form field description = categoryDescription
    When method post
    Then status 201
    And match response.name == categoryName
    * def categoryId = response.id

    Given path 'api', 'categories'
    And param page = 1
    And param limit = 50
    And header Authorization = 'Bearer ' + accessToken
    And header karate-name = 'GET /api/categories'
    When method get
    Then status 200
    And match response.categories == '#[]'

    Given path 'api', 'categories', categoryId
    And header Authorization = 'Bearer ' + accessToken
    And header karate-name = 'PUT /api/categories/:id'
    And form field name = categoryName + ' Updated'
    And form field description = categoryDescription + ' actualizada'
    When method put
    Then status 200
    And match response.id == categoryId
    * def updatedCategoryName = response.name

    Given path 'api', 'books'
    And header Authorization = 'Bearer ' + accessToken
    And header karate-name = 'POST /api/books'
    And form field title = 'Libro Gatling ' + runId
    And form field author = 'QA Gatling'
    And form field isbn = isbn
    And form field publicationYear = 2024
    And form field categoryId = categoryId
    And form field totalQuantity = 1
    And form field availableQuantity = 1
    When method post
    Then status 201
    And match response.isbn == isbn
    * def bookId = response.id

    Given path 'api', 'books'
    And param page = 1
    And param limit = 30
    And header Authorization = 'Bearer ' + accessToken
    And header karate-name = 'GET /api/books'
    When method get
    Then status 200
    And match response.books == '#[]'

    Given path 'api', 'books', bookId
    And header Authorization = 'Bearer ' + accessToken
    And header karate-name = 'PUT /api/books/:id'
    And form field title = 'Libro Gatling actualizado ' + runId
    And form field author = 'QA Gatling'
    And form field isbn = isbn
    And form field publicationYear = 2024
    And form field categoryId = categoryId
    And form field totalQuantity = 1
    And form field availableQuantity = 1
    When method put
    Then status 201
    And match response.id == bookId

    Given path 'api', 'loans'
    And header Authorization = 'Bearer ' + accessToken
    And header karate-name = 'POST /api/loans'
    And form field userId = testUserId
    And form field bookId = bookId
    And form field dueDate = dueDate
    When method post
    Then status 201
    And match response.status == 'ongoing'
    * def loanId = response.id

    Given path 'api', 'loans', loanId, 'return'
    And header Authorization = 'Bearer ' + accessToken
    And header karate-name = 'PUT /api/loans/:id/return'
    When method put
    Then status 200
    And match response.status == 'returned'

    Given path 'api', 'books', bookId
    And header Authorization = 'Bearer ' + accessToken
    And header karate-name = 'DELETE /api/books/:id'
    When method delete
    Then status 204

    Given path 'api', 'categories', categoryId
    And header Authorization = 'Bearer ' + accessToken
    And header karate-name = 'DELETE /api/categories/:id'
    When method delete
    Then status 204
