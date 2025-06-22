Never run xcodebuild
Never check compilation errors
Use latest swift and swiftui
for exampel prefer navigationstack insted of navigationview.
.foregroundStyle instead of foregroundColor
dont create any example usage files, use directly what you create
dont creates any markdown instruction files
keep code clean and modular
never write any tests
If creating api requests via Piped, create extensions for PipedAPI in the API folder
For request paylaods or responses, put raw data structs in Models/PipedData folder
But then also create a simple struct for it under Models which contans the data that we need in our app discarding the rest unnecessary values returned by API
dont manually create any sampel or exampleresponse or requets
Dont create any readme explaining any features
