# StoreKitTest
Swift StoreKitTest

#### Apple在xcode 12提供了一種可以不用利用App Store Connect創建商品以及不需要沙盒 (sandbox) 使用者跟網路就可以在xcode完成內購的測試

#### 第一步：在xcode中創建StoreKit Configuration File
![](http://badgameshow.com/7hong/wp-content/uploads/2021/07/截圖-2021-07-09-下午2.08.58.png)

#### 第二步：點選右下角的 + ，會出現以下選項：
![](http://badgameshow.com/7hong/wp-content/uploads/2021/07/截圖-2021-07-09-下午2.17.34.png)

##### 接著會出現一個內容選單，提供了可以加入的選項：
##### A consumable in-app purchase （一個消耗性的 App 內購項目）
##### A non-consumable in-app purchase（一個非消耗性的 App 內購項目）
##### An auto-renewable subscription（一個自動更新的訂閱服務）
##### 我們想測試非消耗性的 App 內購，因此點擊選單中的第二個選項，你會看到這樣的畫面：
![](http://badgameshow.com/7hong/wp-content/uploads/2021/07/截圖-2021-07-09-下午2.19.42.png)

##### Reference Name 應該包含 App 內購的簡短名字。

##### 而 Product ID 就是產品識別碼，我們也會在 App Store Connect 中提供它。也就是等等下面會介紹到的 getProductIDs() 裡面的 Product ID。

##### 下一個欄位是 App 內購的 Price，雖然在 App Store Connect 有價格等級，但是在這裡我們還是可以以文字提供任意數值。這個價格單純是為了作測試，它並不會是實際的 App 內購價格，當然也不會有收費的動作。

##### 最後，來到 Localizations 的部分。像在 App Store Connect 一樣，我們需要在這裡為 App 內購提供顯示名稱與描述。點選預設的 Localization 欄位，視窗會跳出表單，讓我們將下列數值填入：
![](http://badgameshow.com/7hong/wp-content/uploads/2021/07/截圖-2021-07-09-下午2.29.42.png)

#### 第三步：使用 StoreKit 的配置檔案
##### 創建了 NonConsumables.storekit 檔案並設定好之後，下一步就要告訴我們的 App，我們要使用它而不是 App Store。為了達到這個目的，在 Xcode 工具列點擊 StoreKitLocalDemo 方案，並選擇 Edit Scheme。
![](http://badgameshow.com/7hong/wp-content/uploads/2021/07/截圖-2021-07-09-下午2.32.54.png)

##### 首先，在左側欄位選取 Run，接著在主視窗選擇 Options 頁籤。你會看到下方有一個叫做 StoreKit Configuration 的選項，目前的值應該是 None。點擊彈出按鈕，你應該可以找到剛剛創建的 NonConsumables.storekit 檔案，選擇它之後即可關閉編輯視窗。
![](http://badgameshow.com/7hong/wp-content/uploads/2021/07/截圖-2021-07-09-下午2.33.52.png)

#### 交易管理器 (Transactions Manager)
##### 在之後 App 執行時，點擊 Xcode 狀態列上的 Manage StoreKit Transactions 按鈕：
![](http://badgameshow.com/7hong/wp-content/uploads/2021/07/截圖-2021-07-09-下午2.36.06.png)
##### 就可以管理你購買的商品了。

#### 最後Code的部分：

#### AppDelegate
##### 在appDelegate將 IAPManager 設為 SKPaymentQueue 的 observer，這可以讓使用者啟動 App 時 IAPManager 將可馬上收到通知，觸發 SKPaymentTransactionObserver 的 function，順利完成之前未完的交易
``` swift 
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
	// 初始化
	SKPaymentQueue.default().add(IAPManager.shared)
	
	// 回復使用者之前買過的商品
    SKPaymentQueue.default().restoreCompletedTransactions()
	return true
}

func applicationWillTerminate(_ application: UIApplication) {
	//結束移除
    SKPaymentQueue.default().remove(self)
}
```

##### 創建productID Array (通常會跟server要json下來解，因為你不可能上架一個東西就要修改code，但這邊為了方便就以這樣的方式呈現)
```swift
func getProductIDs() -> [String] {
        ["qpp.iap.basic_free_transfer_charge_1", "qpp.iap.starter_bundle_1", "qpp.iap.bundle_level1_1"]
    }
```

##### 初始化SKProductsRequest
``` swift
func getProducts() {
        // Get the product identifiers.
//        guard let productIDs = getProductIDs() else { return }

        // Initialize a product request.
        let request = SKProductsRequest(productIdentifiers: Set(getProductIDs()))

        // Set self as the its delegate.
        request.delegate = self

        // Make the request.
        request.start()
    }
```

##### getProducts()完成後會觸發 SKProductsRequestDelegate，因此我們需要繼承這個delegate，之後就能依據getProductIDs()給的IDs抓到每個ID的產品資訊(SKProduct)

``` swift
extension IAPManager: SKProductsRequestDelegate {
    // 取得產品資訊
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        response.products.forEach {
            print($0.localizedTitle, $0.price, $0.localizedDescription, $0.productIdentifier)
        }
        self.products = response.products
    }
}
```

##### 購買(將你要購買的商品ID丟進來，告訴SKPaymentQueue你要購買這個商品)
``` swift
func buy(product: SKProduct) {
        // 判斷是否允許購買(有些用戶會把IAP功能關閉，例如：父母親不讓孩子利用IAP購買)
            if SKPaymentQueue.canMakePayments() {
                let payment = SKPayment(product: product)
//                payment.quantity = 1 // 購買數量(預設1)
                SKPaymentQueue.default().add(payment)
            } else {
                // show error
            }
    }
```

##### SKPaymentQueue觸發後，會呼叫SKPaymentTransactionObserver，將可以透過paymentQueue這個func得知交易裝態
``` swift
extension IAPManager: SKPaymentTransactionObserver {
    // 判斷交易的結果
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        transactions.forEach {
            print($0.payment.productIdentifier, $0.transactionState.rawValue)
            switch $0.transactionState {
            // The purchase was successful.
            case .purchased:
                // 交易完成(如未下這行 iOS 會以為交易還未完成，下次打開 App 時會再觸發 paymentQueue(_:updatedTransactions:))
                SKPaymentQueue.default().finishTransaction($0)
                
            // The transaction failed.
            case .failed:
                print($0.error ?? "")
                if ($0.error as? SKError)?.code != .paymentCancelled {
                    // show error
                }
              SKPaymentQueue.default().finishTransaction($0)
                
            // There're restored products.
            case .restored:
              SKPaymentQueue.default().finishTransaction($0)
                
            case .purchasing, .deferred: break
            @unknown default: break
            }
        }
    }
}
```

#### 購買完成後，我們需要認證收據是不是真實的：
##### 這邊我們呼叫apple iap 認證收據的api來確認是否有購買
``` swift
//沙盒測試環境驗證
    let SANDBOX  = "https://sandbox.itunes.apple.com/verifyReceipt"
    
    //正式環境驗證
    let AppStore = "https://buy.itunes.apple.com/verifyReceipt"
	
	func receiptValidation(_ receiptStr: String, url: String = IAPManager.shared.AppStore) {
        #warning("需要 app store connect 的共享密鑰")
        let SUBSCRIPTION_SECRET = "yourpasswordift"
        
        let requestDictionary = ["receipt-data": receiptStr, "password": SUBSCRIPTION_SECRET]
        
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
                            self?.receiptValidation(receiptStr)
                            
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
                    print("the upload task returned an error: \(error ?? QPPError.httpError)")
                }
            }
            task.resume()
        } catch let error as NSError {
            print("json serialization failed with error: \(error)")
        }
    }
```

#### restore 買過的商品
##### 若商品屬於 non-consumable & auto-renewable subscriptions，Apple 還要求 App 必須實作一個功能才能上架，也就是我們現在要介紹的 restore 功能。
##### 實現 restore 功能主要透過以下程式
``` swift
SKPaymentQueue.default().restoreCompletedTransactions()
```
##### 當 restore 成功時，我們可從 paymentQueue(_: updatedTransactions:) 讀取到 transactionState 為 restored，然後開始將商品提供給使用者。

#### 使用
``` swift
IAPManager.shared.buy(product: product)
```

### GitHub
[https://github.com/imacuser111/StoreKitTest](https://github.com/imacuser111/StoreKitTest)
