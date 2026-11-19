import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct ScriptTextTransfer: Transferable {
    let name: String
    let content: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .plainText) { transfer in
            SentTransferredFile(
                try ScriptTextFile.writeExport(
                    name: transfer.name,
                    content: transfer.content
                )
            )
        }
    }
}
