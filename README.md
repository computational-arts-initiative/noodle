# Run:

1. `npm install -g purescript@0.14 spago parcel-bundler`
2. `spago install`
3. `spago -x ./example.dhall build --watch` | `spago -x ./test.dhall test`
4. `parcel --dist-dir ./static index.html`

`purs`, `spago`, `parcel`, `nodemon`


`wget https://hydra.ojack.xyz/bundle.min.js?1.2.6`


# Docker:

`docker build . -t noodle`
`docker run -p 8080:8080 noodle`