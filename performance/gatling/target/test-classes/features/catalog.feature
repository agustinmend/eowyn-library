Feature: Consultas autenticadas del catálogo Eowyn Library

  Background:
    * url baseUrl

  Scenario: Iniciar sesión y consultar libros y categorías
    Given path 'api', 'auth', 'login'
    And header karate-name = 'POST /api/auth/login'
    And form field email = userEmail
    And form field password = userPassword
    When method post
    Then status 200
    And match response.token == '#string'
    * def accessToken = response.token

    Given path 'api', 'categories'
    And param page = 1
    And param limit = categoriesLimit
    And header Authorization = 'Bearer ' + accessToken
    And header karate-name = 'GET /api/categories'
    When method get
    Then status 200
    And match response.categories == '#[]'

    Given path 'api', 'books'
    And param page = 1
    And param limit = booksLimit
    And header Authorization = 'Bearer ' + accessToken
    And header karate-name = 'GET /api/books'
    When method get
    Then status 200
    And match response.books == '#[]'
