import Foundation
import CommonCrypto

final class HEncryptionService {
  
  private let key: String = "5X<#)kRN+)S-2=9A<T,oQk4BUP?ACPVk".asReversed()
  
  func encrypt(message: String) -> String? {
    guard let messageData = message.data(using: .utf8),
          let keyData = key.data(using: .utf8) else { return nil }
    
    let iv = Data(count: kCCBlockSizeAES128)
    var encryptedData = Data(count: messageData.count + kCCBlockSizeAES128)
    var numBytesEncrypted: size_t = 0
    let encryptedDataLength = encryptedData.count
    
    let status = encryptedData.withUnsafeMutableBytes { encBytes in
      messageData.withUnsafeBytes { msgBytes in
        iv.withUnsafeBytes { ivBytes in
          keyData.withUnsafeBytes { keyBytes in
            CCCrypt(
              CCOperation(kCCEncrypt),
              CCAlgorithm(kCCAlgorithmAES),
              CCOptions(kCCOptionPKCS7Padding),
              keyBytes.baseAddress, keyData.count,
              ivBytes.baseAddress,
              msgBytes.baseAddress, messageData.count,
              encBytes.baseAddress, encryptedDataLength,
              &numBytesEncrypted
            )
          }
        }
      }
    }
    
    guard status == kCCSuccess else { return nil }
    
    let cipherData = encryptedData.prefix(numBytesEncrypted)
    let finalData = iv + cipherData
    return finalData.base64EncodedString()
  }
  
}

extension String {
  func asReversed() -> String {
    String(self.reversed())
  }
}
