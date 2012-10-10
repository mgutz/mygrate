module.exports = {
  development: {
    postgresql: {
      host: "localhost",
      database: "db_development",
      user: "development",
      password: "!development"
    }
  },
  test: {
    postgresql: {
      host: "localhost",
      database: "db_test",
      user: "test",
      password: "!test"
    }
  },
  production: {
    postgresql: {
      host: "localhost",
      database: "db_production",
      user: "production",
      password: "!production"
    }
  }
};
