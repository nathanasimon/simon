# Maintainer: Nathan Simon <nathanaaronsimon@gmail.com>
pkgname=simon
pkgver=0.1.0
pkgrel=1
pkgdesc="Memory for Claude Code — records sessions, injects context, generates skills"
arch=('any')
url="https://github.com/nathanasimon/simon"
license=('MIT')
depends=(
    'python>=3.11'
    'python-sqlalchemy'
    'python-asyncpg'
    'python-anthropic'
    'python-httpx'
    'python-pydantic'
    'python-pydantic-settings'
    'python-typer'
    'python-rich'
)
makedepends=('python-build' 'python-installer' 'python-setuptools' 'python-wheel')
source=("$pkgname-$pkgver.tar.gz::https://github.com/nathanasimon/simon/archive/v$pkgver.tar.gz")
sha256sums=('SKIP')

build() {
    cd "$pkgname-$pkgver"
    python -m build --wheel --no-isolation
}

package() {
    cd "$pkgname-$pkgver"
    python -m installer --destdir="$pkgdir" dist/*.whl
    install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
