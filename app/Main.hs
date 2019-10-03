{-# LANGUAGE OverloadedLabels  #-}
{-# LANGUAGE OverloadedLists   #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import           Data.Text                      ( Text )
import qualified Data.Text                     as T
import qualified Data.Text.IO                  as T
import qualified Data.Text.Encoding            as T
import           Control.Monad
import           Control.Applicative
import           Control.Concurrent.Async       ( async )
import qualified GI.Gdk                        as Gdk
import qualified GI.Gtk                        as Gtk
import qualified Data.ByteString.Char8         as BS
import           GI.Gtk.Declarative
import           GI.Gtk.Declarative.App.Simple
import           System.IO.Unsafe
import           Bene.Renderer
import           Paths_bene
import           Control.Monad.Trans.State
import           Control.Monad.IO.Class
import           Control.Monad.Trans.Class

data Screen = Welcome | Editing | Save | Open

data Luggage = Luggage { screen   :: Screen
                       , buffer   :: Gtk.TextBuffer
                       , filename :: Maybe FilePath }

type AppState a = State Luggage a

data Event = Closed
           | OpenFileSelected (Maybe FilePath)
           | NewClicked
           | OpenClicked
           | Typed
           | SaveClicked
           | SaveFileSelected (Maybe FilePath)

-- | Create an empty TextBuffer.
createBuffer :: Gtk.TextBuffer
createBuffer = unsafePerformIO $ do
  buffer <- Gtk.textBufferNew . Just =<< markdownTextTagTable
  Gtk.on buffer #endUserAction (renderMarkdown buffer)
  return buffer

-- | Constructs a FileFilter which pertains to Markdown documents.
markdownFileFilter :: IO Gtk.FileFilter
markdownFileFilter = do
  filt <- Gtk.fileFilterNew
  Gtk.fileFilterSetName filt $ Just "Markdown documents"
  Gtk.fileFilterAddMimeType filt "text/markdown"
  Gtk.fileFilterAddMimeType filt "text/x-markdown"
  Gtk.fileFilterAddPattern filt "**/*.{markdown,md}"
  return filt

-- | Create a TextView widget from a given TextBuffer.
editor :: Gtk.TextBuffer -> Widget Event
editor buffer = widget
  Gtk.TextView
  [ afterCreated setBuffer
  , #wrapMode := Gtk.WrapModeWord
  , #margin := 10
  , classes ["editor"]
  ]
  where setBuffer tv = Gtk.textViewSetBuffer tv $ Just buffer

-- | Render Markdown based on the content of a TextBuffer.
renderMarkdown :: Gtk.TextBuffer -> IO ()
renderMarkdown buffer = clearTags buffer >> formatBuffer buffer

-- | Remove all TextTags from a buffer.
clearTags :: Gtk.TextBuffer -> IO ()
clearTags buffer = do
  s <- Gtk.textBufferGetStartIter buffer
  e <- Gtk.textBufferGetEndIter buffer
  Gtk.textBufferRemoveAllTags buffer s e

getBufferContents :: Gtk.TextBuffer -> IO Text
getBufferContents buffer = do
  s <- Gtk.textBufferGetStartIter buffer
  e <- Gtk.textBufferGetEndIter buffer
  Gtk.textBufferGetText buffer s e True

-- | Place a widget inside a BoxChild and allow it to expand.
expandableChild :: Widget a -> BoxChild a
expandableChild =
  BoxChild defaultBoxChildProperties { expand = True, fill = True }

view' :: AppState (AppView Gtk.Window Event)
view' = do
  s <- gets screen
  b <- gets buffer
  return
    $ bin
        Gtk.Window
        [ #title := "Bene"
        , on #deleteEvent (const (True, Closed))
        , #widthRequest := 480
        , #heightRequest := 300
        ]
    $ case s of
        Welcome ->
          container Gtk.Box [#orientation := Gtk.OrientationHorizontal]
            $ [ expandableChild $ widget
                Gtk.ToolButton
                [ #iconName := "document-new"
                , on #clicked NewClicked
                , classes ["intro"]
                ]
              , expandableChild $ widget
                Gtk.ToolButton
                [ #iconName := "document-open"
                , on #clicked OpenClicked
                , classes ["intro"]
                ]
              ]
        Editing ->
          container Gtk.Box [#orientation := Gtk.OrientationVertical]
            $ [expandableChild $ bin Gtk.ScrolledWindow [] $ editor b, expandableChild $ widget Gtk.Button [on #clicked SaveClicked]]
        Save -> widget
          Gtk.FileChooserWidget
          [ #action := Gtk.FileChooserActionOpen
          , onM #fileActivated (fmap SaveFileSelected . Gtk.fileChooserGetFilename)
          ]


update' :: Luggage -> Event -> Transition Luggage Event
update' s NewClicked                     = Transition s { screen = Editing } $ return Nothing
update' s SaveClicked                    = Transition s { screen = Save } $ return Nothing
update' s (SaveFileSelected (Just file)) = Transition s { screen = Editing } $ return Nothing
update' _ _          = Exit

main :: IO ()
main = do
  void $ Gtk.init Nothing

  path     <- T.pack <$> getDataFileName "themes/giorno/giorno.css"
  screen   <- maybe (fail "No screen?") return =<< Gdk.screenGetDefault
  provider <- Gtk.cssProviderNew

  Gtk.cssProviderLoadFromPath provider path
  Gtk.styleContextAddProviderForScreen
    screen
    provider
    (fromIntegral Gtk.STYLE_PROVIDER_PRIORITY_USER)

  void . async $ do
    runLoop app
    Gtk.mainQuit
  Gtk.main
 where
  app = App { view         = evalState view'
            , update       = update'
            , inputs       = []
            , initialState = Luggage Welcome createBuffer Nothing
            }
