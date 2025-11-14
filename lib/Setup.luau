--!strict

local Meta = require('@lorry.utils/lib/Meta')
local Lorry = require("@lorry.utils/lib/Lorry")
local Yaml = require("@lorry.utils/lib/Yaml")
local Usql = require('@lorry.utils-usql/lib/Usql')

export type Config = {
  project: {
    name: string,
  },
  backend: any,
  compose: any,
  migrate: any,
  ['admin-ui']: any,
  database: {
    type: 'postgres' | 'mysql',
    ['connection-string']: string,
    ['table-whitelist']: {string}?,
    ['table-blacklist']: {string}?,
    ['schema-whitelist']: {string}?,
    ['schema-blacklist']: {string}?,
    ['catalog-whitelist']: {string}?,
    ['catalog-blacklist']: {string}?,
  }
}

export type SetupProps = {
  config: Config,
}

local Setup = {}

export type Setup = typeof(Setup)

export type SetupImpl = Setup & SetupProps

function Setup:new(o: SetupProps): Setup
  return Meta:type(o, self, 'Setup')
end

function Setup:from_path(path: string): Setup
  local config: Config = Yaml:from_file(path)
  return Setup:new({
    config = config
  })
end

function Setup:generate()
  local this = self::SetupImpl

  local database = Usql
    :from_config 'usql-config.yaml'
    :database(this.config.database["connection-string"])
    :universal(this.config.database.type)

  local filter = {
    catalog_blacklist = this.config.database["catalog-blacklist"],
    catalog_whitelist = this.config.database["catalog-whitelist"],
    schema_blacklist = this.config.database["schema-blacklist"],
    schema_whitelist = this.config.database["schema-whitelist"],
    table_blacklist = this.config.database["table-blacklist"],
    table_whitelist = this.config.database["table-whitelist"],
  }

  local entities = database:filter_table_entities(nil, filter)

  local catalogs_map = Meta:table {}
  local schemas_map = Meta:table {}

  local catalogs = Meta:array {}
  local schemas = Meta:array {}

  for i, e in entities do
    local catalog_name = e.table.table_catalog
    local schema_name = `{e.table.table_catalog}.{e.table.table_schema}`
    if catalogs_map[catalog_name] == nil then
      catalogs_map[catalog_name] = e.catalog
      catalogs[#catalogs + 1] = e.catalog
    end
    if schemas_map[schema_name] == nil then
      schemas_map[schema_name] = e.catalog
      schemas[#schemas + 1] = e.schema
    end
  end

  local db = {
    -- catalogs = database:filter_catalog_records(nil, filter),
    -- schemas = database:filter_schema_records(nil, filter),
    -- tables = database:filter_table_records(nil, filter),
    catalogs = catalogs,
    schemas = schemas,
    entities = database:filter_table_entities(nil, filter),
  }

  Lorry:generate "@lorry.preset-web/setup" {
    target = "@root",
    variables = {
      config = this.config
    }
  }

  if this.config.backend ~= nil then
    Lorry:generate "@lorry.preset-web/setup-spring-backend" {
      target = "@root",
      variables = {
        config = this.config,
        db = db,
      }
    }
  end

  if this.config['admin-ui'] ~= nil then
    Lorry:generate "@lorry.preset-web/setup-admin-ui" {
      target = "@root",
      variables = {
        config = this.config,
        db = db,
      }
    }
  end

  if this.config.compose ~= nil then
    Lorry:generate "@lorry.preset-web/setup-compose" {
      target = "@root",
      variables = {
        config = this.config,
        db = db,
      }
    }
  end
end

return Setup
