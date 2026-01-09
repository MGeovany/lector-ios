import Foundation

enum BookTextProvider {
  static func pages(for book: Book) -> [String] {
    // TODO: Replace with real document page loading (EPUB/TXT/PDF parsing).
    // Important: In the real implementation, pages should come pre-split by the document.
    // The Reader should render each page as-is (no re-pagination by layout).
    switch book.title.lowercased() {
    case "noches blancas":
      // Larger per-page content so scroll is meaningful.
      return SamplePages.pages(from: SampleTexts.nochesBlancas, pageLength: 2400)
    case "meditations":
      return SamplePages.pages(from: SampleTexts.meditations, pageLength: 900)
    case "the pragmatic programmer":
      return SamplePages.pages(from: SampleTexts.pragmaticProgrammer, pageLength: 1100)
    default:
      return SamplePages.pages(from: SampleTexts.generic(title: book.title), pageLength: 1100)
    }
  }

  static func fullText(for book: Book) -> String {
    pages(for: book).joined(separator: "\n\n")
  }
}

private enum SampleTexts {
  static let nochesBlancas: String = SampleTexts.makeNochesBlancasLong()

  static let meditations: String = """
    You have power over your mind — not outside events. Realize this, and you will find strength.

    The happiness of your life depends upon the quality of your thoughts.

    Waste no more time arguing what a good person should be. Be one.

    If it is not right, do not do it; if it is not true, do not say it.
    """

  static let pragmaticProgrammer: String = """
    Care about your craft. Think! About your work.

    Provide options, don't make lame excuses.

    Don't live with broken windows.

    Make it easy to reuse. Make it easy to do the right thing.
    """

  static func generic(title: String) -> String {
    """
    \(title)

    Este es un texto de ejemplo para previsualizar la lectura por páginas.

    La idea es que puedas abrir un libro y navegar por páginas con una UI limpia: título, autor, tiempo estimado de lectura y controles inferiores para avanzar/retroceder.

    Cuando conectemos el importador real (TXT/EPUB/PDF), este contenido se reemplazará automáticamente por el del documento.
    """
  }

  private static func makeNochesBlancasLong() -> String {
    let base: String = """
      Como si estuviese leyendo algo escrito, porque hacía ya tiempo que había pronunciado sentencia contra mí mismo y ahora no había resistido la tentación de leerla, sin esperar, por supuesto, que se me comprendiera.

      Pero, con sorpresa mía, Nastenka siguió callada y luego me estrechó la mano y me dijo con tímida simpatía:

      —¿Es posible que haya vivido usted toda su vida como dice? —Toda mi vida, Nastenka —contesté—. Toda ella, y al parecer así la acabaré.

      —No, imposible —replicó intranquila—. Eso no. Puede que yo también pase la vida entera junto a mi abuela. Oiga, ¿sabe que vivir de esa manera no es nada bonito?

      —Lo sé, Nastenka, lo sé —exclamé sin poder contener mi emoción—. Ahora más que nunca sé que he malgastado mis años mejores.

      Ahora lo sé, y ese conocimiento me causa pena, porque Dios mismo ha sido quien me ha enviado a usted, a mi ángel bueno, para que me lo diga y me lo demuestre.

      Ahora que estoy sentado junto a usted y que hablo con usted me aterra pensar en el futuro, porque el futuro es otra vez la soledad, esta vida rutinaria e inútil.

      ¡Y ya con qué voy a soñar, cuando he sido tan feliz despierto! ¡Bendita sea usted, niña querida, por no haberme rechazado desde el primer momento, por haberme dado la posibilidad de decir que he vivido al menos dos noches en mi vida!
      """

    let separator = "\n\n• • •\n\n"
    let chapter2 = """
      CAPÍTULO 2

      —¡Oh, no, no! —exclamó Nastenka con lágrimas—. Eso ya no pasará. No vamos a separarnos así.
      ¿Qué es eso de dos noches?

      —Ay, Nastenka, Nastenka… ¿Sabe usted por cuánto tiempo me ha reconciliado conmigo mismo? ¿Sabe usted cuán diferente se vuelve el mundo cuando, por un instante, uno se siente comprendido?
      """

    // Repeat enough times to test scrolling and to guarantee multiple pages on any device.
    let repeated = Array(repeating: base, count: 10).joined(separator: separator)
    return repeated + separator + chapter2 + separator + repeated
  }
}

private enum SamplePages {
  static func pages(from text: String, pageLength: Int) -> [String] {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [""] }
    guard pageLength > 40 else { return [trimmed] }

    // Split by fixed character count (simulating "document-provided pages").
    // This intentionally does NOT depend on font/size/layout.
    var result: [String] = []
    var start = trimmed.startIndex

    while start < trimmed.endIndex {
      let end =
        trimmed.index(start, offsetBy: pageLength, limitedBy: trimmed.endIndex) ?? trimmed.endIndex
      let chunk = String(trimmed[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
      result.append(chunk)
      start = end
    }

    // Ensure at least 2 pages for pagination testing.
    if result.count == 1, let only = result.first, only.count > 200 {
      let mid =
        only.index(only.startIndex, offsetBy: 200, limitedBy: only.endIndex) ?? only.endIndex
      result = [
        String(only[..<mid]).trimmingCharacters(in: .whitespacesAndNewlines),
        String(only[mid...]).trimmingCharacters(in: .whitespacesAndNewlines),
      ]
    }

    return result
  }
}
