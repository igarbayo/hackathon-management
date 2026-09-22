# Hackboard

Herramienta de gestión para equipos de hackathon. La documentación funcional vive en [`specs/`](specs/README.md); léela antes de tocar código.

## Desarrollo local

Requiere Docker.

```sh
cp apps/api/.env.example apps/api/.env
cp apps/web/.env.example apps/web/.env.local
docker compose up
```

- `web`: http://localhost:3000
- `api`: http://localhost:3001

## Tests

```sh
# api (Rails + Mongoid)
docker compose run --rm -e RAILS_ENV=test -e MONGODB_URI=mongodb://mongo:27017/hackboard_test -e REDIS_URL=redis://redis:6379/1 api bundle exec rspec

# web, cli, shared-schemas
npm test --workspaces
```
