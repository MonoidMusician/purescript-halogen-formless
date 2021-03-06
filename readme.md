# Formless

[![CircleCI](https://circleci.com/gh/thomashoneyman/purescript-halogen-formless/tree/master.svg?style=shield)](https://circleci.com/gh/thomashoneyman/purescript-halogen-formless/tree/master)
[![Maintainer: thomashoneyman](https://img.shields.io/badge/maintainer-thomashoneyman-lightgrey.svg)](http://github.com/thomashoneyman)

Formless is a renderless component which helps you build forms in Halogen. Its goal is to abstract away the tedious, dirty bits of building forms without imposing any particular rendering or validation strategies on your design.

- [Example / Documentation Site](https://thomashoneyman.github.io/purescript-halogen-formless/)

## Use

Install with Bower:

```sh
bower i --save purescript-halogen-formless
```

In general, Formless only requires that you provide a form data type, a render function, and a validation function. The component will handle all the wiring for updating fields on change or blur, running validation, managing dirty states, and the other tedious work of building a large form. On failed submission, see errors; on successful submission, see just the output values you care about.

Your render function and validation function can use any of the information that Formless preserves about the state of your form at any given moment. You are only expected to provide an initial value and validator, but Formless will generate a lot more information about the state of each field that you can use in rendering / validation.

Since Formless is a renderless component, you can freely extend it with new behaviors with the Raise/Emit pattern. You can freely render and send queries to external components and they'll still work with Formless.

### FormSpec

You are expected to provide a form spec that looks like this:

```purescript
newtype Form f = Form
  { email :: f String (NonEmptyList MyError) Email }
derive instance newtypeForm :: Newtype Form _
```

The `f` type parameter will be filled in by various other types, each of which expect an input, error, and result type (the three types above). The component expects that you provide this type applied to the Formless `FormSpec` type:

```purescript
formSpec :: Form Formless.Spec.FormSpec
formSpec = Form
  { email: FormSpec "" }

-- You can also use the mkFormSpec helper to avoid writing newtypes:
formSpec :: Form Formless.Spec.FormSpec
formSpec = Formless.Spec.mkFormSpec { email: "" }
```

#### More Advanced Form Specs

You can avoid creating a form spec value at all, and just have Formless derive it from your `Form` newtype, so long as all of the fields in the form have input types with an `Initial` instance. Any monoidal value is fine, and if you have a custom value, you'll simply need to provide what the initial value ought to be.

For large forms this can save a lot of typing.

```purescript
newtype Form f = Form (Record (FormRow f))
derive instance newtypeForm :: Newtype (Form f) _

type FormRow f =
  ( name :: f String String String
  , email :: f String Void String
  , age :: f String String Int
  )

formSpec :: Form Formless.Spec.FormSpec
formSpec = Formless.Spec.mkFormSpecFromRow row
  where
    row = RProxy :: RProxy (FormRow Formless.Spec.Input)
```

### Validation

Formless does not provide any validation for you. Instead, you can write your own validation based on `purescript-validation`'s `V` type, `purescript-polyform`'s monadic `Validation` type, stick with a traditional approach with `Either`, or whatever failure type you want. The only restriction Formless places on you is that your type can be transformed into what it uses to maintain errors under the hood:

```purescript
-- Maybe represents whether the field was validated in the first place
-- Either represents failure or success
{ result :: Maybe (Either error output) }

-- Your validation function must have this type, in which you can freely perform monadic or applicative-style validation:
validate :: MyForm InputField -> m (MyForm InputField)
```

If you use common libraries like `purescript-validation` or `purescript-polyform`, there are helper functions that will perform this transformation for you.

For example, the `onInputField` function takes a function `i -> V e o` and converts it to work properly on Formless's underlying types.

```purescript
{ myField: (\i -> validateNonEmpty i *> validateMinimumLength i 7) `onInputField` myField }
```

See the examples for more.

## Examples

There are several examples of forms built with Formless, from simple (a few text fields) to involved (mounting external components) to complex (implementing dependent validation and behaviors in the form).

All examples are located in the `/example` folder. You can view the code there, but there is also a fully-functioning storybook application you can use to interact with the examples.

If you'd simply like to view the running example code, view the [documentation site](https://thomashoneyman.github.io/purescript-halogen-formless/).

If you'd like to build and edit the examples:

```sh
# Clone the repository to 'formless'
git clone git@github.com:thomashoneyman/purescript-halogen-formless formless

# Change into the project directory
cd formless

# Install NPM and Bower dependencies
yarn

# Build the library and examples
yarn build-all

# View the application
open dist/index.html
```

### Other Notes

This library depends on `purescript-halogen-renderless` for helper functions and the original template for the renderless component. If you would like to learn more about how to build these components, or you're ready to build your own, see the library:

- [purescript-halogen-renderless](https://github.com/thomashoneyman/purescript-halogen-renderless)

Examples are implemented using the Ocelot design system by CitizenNet. If you find this confusing, ignore the HTML and focus on the events and the data.

- [purescript-ocelot](https://github.com/citizennet/purescript-ocelot)
