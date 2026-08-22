
How to wrap attributed properties

Here's the pattern. Say you have a property XYZ in FigureDetailView. Find where it's displayed — e.g.:
Text(figure.XYZ)
    .font(.callout)
Wrap it with AttributedPropertyView:
AttributedPropertyView(attributions: figureAttributions, propertyName: "XYZ") {
    Text(figure.XYZ)
        .font(.callout)
}
Key points:
- figureAttributions is the computed property already on the view that pulls figure.contentAttributions
- propertyName is the string you'd type into the property picker in ContentAttributionFormView — must match exactly
- @ViewBuilder lets you wrap any view content (plain Text, RichTextDisplay, HStack of multiple elements, etc.)
- If no ContentAttribution with that propertyName exists, it renders the content unchanged (no badge)