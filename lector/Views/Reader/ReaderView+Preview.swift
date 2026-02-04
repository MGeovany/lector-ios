import SwiftUI

@MainActor
private func makeReaderPreviewPreferences() -> PreferencesViewModel {
  let prefs = PreferencesViewModel()
  prefs.theme = .day
  prefs.font = .georgia
  prefs.fontSize = 18
  prefs.lineSpacing = 1.15
  return prefs
}

#Preview("Reader • Test text") {
  let sampleText =
    """
    Capítulo 1 — Texto de prueba

    Este es un texto de prueba para previsualizar el lector. La idea es tener varios párrafos, con saltos de línea, para validar tipografía, espaciado y paginación.

    Cuando el usuario cambia el tamaño de letra (AA) o el tema, el contenido debe seguir siendo cómodo de leer. También queremos verificar cómo se ve un título largo y cómo se comporta el paginador.

    ——

    Párrafo extra: Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec in urna sit amet massa viverra egestas. Sed at elit nec justo ullamcorper aliquet.

    Fin.Capítulo 2 — Otra página de prueba Esta segunda sección existe para asegurar que el preview genere múltiples páginas y podamos probar navegación, search, y estilos en un bloque más largo.

    Un texto más largo ayuda a detectar cortes raros, saltos de línea inesperados, y problemas de layout. También permite probar la búsqueda dentro del libro con varias coincidencias.


    Esta segunda sección existe para asegurar que el preview genere múltiples páginas y podamos probar navegación, search, y estilos en un bloque más largo.

    Un texto más largo ayuda a detectar cortes raros, saltos de línea inesperados, y problemas de layout. También permite probar la búsqueda dentro del libro con varias coincidencias.

    Esta segunda sección existe para asegurar que el preview genere múltiples páginas y podamos probar navegación, search, y estilos en un bloque más largo.

    Un texto más largo ayuda a detectar cortes raros, saltos de línea inesperados, y problemas de layout. También permite probar la búsqueda dentro del libro con varias coincidencias.


    Esta segunda sección existe para asegurar que el preview genere múltiples páginas y podamos probar navegación, search, y estilos en un bloque más largo.

    Un texto más largo ayuda a detectar cortes raros, saltos de línea inesperados, y problemas de layout. También permite probar la búsqueda dentro del libro con varias coincidencias.


    Repite: cthulhu cthulhu cthulhu.
    """

  let book = Book(
    title: "Reader Preview 2",
    author: "Fiodor Doestoyevski",
    pagesTotal: 2,
    currentPage: 1,
    sizeBytes: 0,
    lastOpenedDaysAgo: 0,
    isRead: false,
    isFavorite: false,
    tags: ["ARTICLE"]
  )

  NavigationStack {
    ReaderView(book: book, initialText: sampleText)
      .environmentObject(makeReaderPreviewPreferences())
  }
}
