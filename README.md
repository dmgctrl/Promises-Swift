## About
A library that implements Promises in Swift 2.0.

Promises are a great way to deal with asynchronous operations such as networking.
They also offer a convenient way to deal with internal async methods like animations and file operations. We have taken a minimal approach which allows the user to control many aspects of how promises are used. Compared to other Swift Promise implementations, this library aims to be simple, fast, and extremely light-weight.


## Installation
### Carthage
```
github "dmgctrl/Promises-Swift" ~> 1.2.7
```

## Use Cases
Take a simple networking scenario, you have a view that needs some data, and you have a class that wraps all of your networking functionality. In most cases you would end up with something like the following:

```
// Network.swift
func httpGet(request: NSURLRequest!, callback: (NSData, String?) -> Void) {
    let session = NSURLSession.sharedSession()
    let task = session.dataTaskWithRequest(request) { data, response, error -> Void in
        if nil == error {
          callback(data!, nil)
        } else {
            callback("", error!.localizedDescription)
        }
    }
    task.resume()
}

// ViewController.swift
let googleRequest = NSMutableURLRequest(URL: NSURL(string: "http://www.google.com")!)
httpGet(googleRequest) { data, error -> Void in
    if error != nil {
        print(error)
    } else {
        print(data)
        dispatch_async(dispatch_get_main_queue()) {
          // Do UI stuff...
        }
    }
}
```

This works just fine for our simple case, but will need to wrap your UI code in a call to `dispatch_async` in order to force your UI code to run on the main Queue since you have no choice which Queue your callback runs on. This is a solution that will work, but can become very cumbersome, especially if you are doing more complicated stuff.

(In more complex cases you will most likely run into the infamous [Pyramid of Doom](https://en.wikipedia.org/wiki/Pyramid_of_doom_(programming))

Promises attempt to solve this problem by giving you access to the completion and error cases inline while also giving you control over the Queue that your completion and error code runs on.

Have a look at a updated version of the code above that uses Promises.

```
// Network.swift
import Promises

func httpGet(request: NSURLRequest!) -> Promise<NSData> {
    return promise { resolve, reject in
      let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(request) { data, response, error -> Void in
          if nil == error {
                resolve(data!)
            } else {
                reject(error!)
            }
        }
        task.resume()
    }
}

// ViewController.swift
let googleRequest = NSMutableURLRequest(URL: NSURL(string: "http://www.google.com")!)
httpGet(googleRequest).then(on: .Main) { data in
    // Do Stuff
}.error { error in
    // fail
}
```

If we break down what is happening here, we can see a couple of improvements to the code.

First, we no longer need to pass a callback to our networking function `httpGet`.
This cleans up the method signature and also gives a nice clear indication of what we expect this function to return.

Second, we can clearly see in `httpGet` how we are handling success and failure. There are a few benefits over the callback example, first we can clearly see in the method where success and failure happen. Also, this eliminates the need to for users to check for errors on the other side.

Third, the user of `httpGet` can now run code that applies to each case separately. Our success happens in the `.then` block and our error is handled in the `.error` block, no more redundantly inspecting the parameters of a callback. In this case, if we do not get an error case, we do not run our error code and vice versa if we get an error.

Finally, notice that we have removed the call to `dispacth_async` since now we can control the Queue on which our code is executed by using the `on` parameter of `.then`. By default we rely on GCD to put our code on whatever queue it sees fit, but if you specify `.Main`, you are telling GCD that you want to run on the main queue.


## Useful Methods

##### `.always`

Allows you to run a block of code after a promise executes regardless of whether it passes or fails.

##### `.recover`

Schedules a block to be executed on the given execution queue, when the promise resolves to an error and uses the block's result as the resolution to a new promise.  this allows an error to be converted into success.

##### `when`

Takes an array of promises and waits for all of them to complete. The return value is a tuple that contains the result of each promise in the order they were passed in.

##### `first`

Takes an array of promises and resolves with the value of the first one. This is useful for cases where you may be hitting an API that offers several endpoints for the same operation. You can fire off a request for each one and get your value back from the fastest server.

# License

Copyright 2015, Tonic Design; <help@tonicdesign.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
