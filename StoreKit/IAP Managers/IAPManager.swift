//
//  IAPManager.swift
//  StoreKitLocalDemo
//

import SwiftUI
import StoreKit

class IAPManager: NSObject, ObservableObject {
    
    // MARK: - Custom Types
    
    enum IAPManagerError: Error {
        case noProductIDsFound
        case noProductsFound
        case paymentWasCancelled
        case productRequestFailed
        case httpError
    }
    
    
    static let shared = IAPManager()
    
    @Published var products = [SKProduct]()
    
    //沙盒測試環境驗證
    let SANDBOX  = "https://sandbox.itunes.apple.com/verifyReceipt"
    
    //正式環境驗證
    let AppStore = "https://buy.itunes.apple.com/verifyReceipt"
    
    private var productIdentifier = ""
    
    override init() {
        super.init()
        _ = getProductIDs()
    }
    
    // MARK: - General Methods
    
    func getProductIDs() -> [String]? {
        guard let url = Bundle.main.url(forResource: "IAP_ProductIDs", withExtension: "plist") else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let productIDs = try PropertyListSerialization.propertyList(from: data, options: .mutableContainersAndLeaves, format: nil) as? [String] ?? []
            getProducts(productIDs)
            return productIDs
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    func startObserving() {
        SKPaymentQueue.default().add(self)
    }


    func stopObserving() {
        SKPaymentQueue.default().remove(self)
    }
    
    // MARK: - Get IAP Products
    
    func getProducts(_ productIDs: [String]) {
        // Initialize a product request.
        let request = SKProductsRequest(productIdentifiers: Set(productIDs))
        
        // for test Configuration 訂閱
        //        let request = SKProductsRequest(productIdentifiers: Set(["com.iap.subscription"]))
        
        // Set self as the its delegate.
        request.delegate = self
        
        // Make the request.
        request.start()
    }
    
    // MARK: - Purchase Products
    
    func buy(product: SKProduct) {
        // 判斷是否允許購買(有些用戶會把IAP功能關閉)
        if SKPaymentQueue.canMakePayments() {
            productIdentifier = product.productIdentifier
            
            let payment = SKPayment(product: product)
            //                payment.quantity = 1 // 購買數量(預設1)
            SKPaymentQueue.default().add(payment)
        } else {
            // show error
        }
    }
}

extension IAPManager: SKProductsRequestDelegate {
    // 取得產品資訊
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        response.products.forEach {
            print($0.localizedTitle, $0.price, $0.localizedDescription, $0.productIdentifier)
        }
        
        DispatchQueue.main.async {
            self.products = response.products
        }
    }
}

extension IAPManager: SKPaymentTransactionObserver {
    // 判斷交易的結果
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        transactions.forEach {
            print($0.payment.productIdentifier, $0.transactionState.rawValue)
            switch $0.transactionState {
            // The purchase was successful.
            case .purchased:
                if !getReceipt().isEmpty {
                    // call apple api post
                    receiptValidation(getReceipt())
                    
                    // 交易完成(如未下這行 iOS 會以為交易還未完成，下次打開 App 時會再觸發 paymentQueue(_:updatedTransactions:))
                    SKPaymentQueue.default().finishTransaction($0)
                }
                
            // The transaction failed.
            case .failed:
                print($0.error ?? "")
                if ($0.error as? SKError)?.code != .paymentCancelled {
                    // show error
                }
                SKPaymentQueue.default().finishTransaction($0)
                
            // There're restored products.
            case .restored:
                // get receipt
                if !getReceipt().isEmpty {
                    // call apple api post
                    receiptValidation(getReceipt())
                }
                
                SKPaymentQueue.default().finishTransaction($0)
                
            case .purchasing, .deferred: break
            @unknown default: break
            }
        }
    }
}

// MARK: - call apple receipt Api
extension IAPManager {
    func receiptValidation(_ receiptStr: String, url: String = IAPManager.shared.AppStore) {
        #warning("需要 app store connect 的共享密鑰")
        let SUBSCRIPTION_SECRET = ""
        
        //        let requestDictionary = ["receipt-data": receiptStr, "password": SUBSCRIPTION_SECRET]
        let requestDictionary = ["receipt-data": receiptStr]
        
        guard JSONSerialization.isValidJSONObject(requestDictionary) else {  print("requestDictionary is not valid JSON");  return }
        do {
            let requestData = try JSONSerialization.data(withJSONObject: requestDictionary)
            let validationURLString = url  // this works but as noted above it's best to use your own trusted server
            guard let validationURL = URL(string: validationURLString) else { print("the validation url could not be created, unlikely error"); return }
            let session = URLSession(configuration: URLSessionConfiguration.default)
            var request = URLRequest(url: validationURL)
            request.httpMethod = "POST"
            request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringCacheData
            let task = session.uploadTask(with: request, from: requestData) { [weak self] (data, response, error) in
                if let data = data , error == nil {
                    do {
                        guard let appReceiptJSON = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                        print("success. here is the json representation of the app receipt: \(appReceiptJSON["status"] ?? "")")
                        
                        switch appReceiptJSON["status"] as? Int {
                        // success
                        case 0:
                            print(appReceiptJSON)
                            
                        // 對 App Store 的請求不是使用 HTTP POST 請求方法發出的
                        case 21000: break
                            
                        // receipt-data屬性中的數據格式錯誤或服務遇到臨時問題。再試一次
                        case 21002:
                            #warning("可能會造成無限遞迴")
                        //                            self?.receiptValidation(receiptStr)
                        
                        // 收據無法驗證
                        case 21003: break
                            
                        // 您提供的共享機密與您帳戶中存檔的共享機密不匹配
                        case 21004: break
                            
                        // 收據服務器暫時無法提供收據。再試一次
                        case 21005: break
                            
                        // 此收據有效，但訂閱已過期。當此狀態代碼返回到您的服務器時，接收數據也會被解碼並作為響應的一部分返回。僅針對自動續訂訂閱的 iOS 6 樣式交易收據返回
                        case 21006: break
                            
                        // 這個收據是來自測試環境，但是是送到生產環境去驗證的
                        case 21007:
                            self?.receiptValidation(receiptStr, url: self?.SANDBOX ?? "")
                            
                        // 這個收據是來自生產環境，但是被送到了測試環境進行驗證
                        case 21008: break
                            
                        // 內部數據訪問錯誤。稍後再試
                        case 21009: break
                            
                        // 用戶帳戶無法找到或已被刪除
                        case 21010: break
                            
                        default: break
                        }
                        // if you are using your server this will be a json representation of whatever your server provided
                    } catch let error as NSError {
                        print("json serialization failed with error: \(error)")
                    }
                } else {
                    print("the upload task returned an error: \(error ?? IAPManagerError.httpError)")
                }
            }
            task.resume()
        } catch let error as NSError {
            print("json serialization failed with error: \(error)")
        }
    }
}

extension NSObject {
    func getReceipt() -> String {
        // Get the receipt if it's available
        if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
           FileManager.default.fileExists(atPath: appStoreReceiptURL.path) {
            
            do {
                let receiptData = try Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)
                print(receiptData)
                
                let receiptString = receiptData.base64EncodedString(options: [])
                
                // Read receiptData
                return receiptString
            }
            catch { print("Couldn't read receipt data with error: " + error.localizedDescription) }
        }
        return ""
    }
}

extension SKProduct {
    // 依據使用者帳號所在的國家回傳正確的金額
    var regularPrice: String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = self.priceLocale
        return formatter.string(from: self.price)
    }
}

// MARK: - IAPManagerError Localized Error Descriptions
extension IAPManager.IAPManagerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noProductIDsFound: return "No In-App Purchase product identifiers were found."
        case .noProductsFound: return "No In-App Purchases were found."
        case .productRequestFailed: return "Unable to fetch available In-App Purchase products at the moment."
        case .paymentWasCancelled: return "In-App Purchase process was cancelled."
        case .httpError: return "httpError"
        }
    }
}
