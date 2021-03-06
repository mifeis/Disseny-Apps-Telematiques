
{-# LANGUAGE OverloadedStrings #-}

module Handler
where
import View
import Found
import Model

import Develop.DatFw
import Develop.DatFw.Handler
import Develop.DatFw.Template
import Develop.DatFw.Widget
import Develop.DatFw.Auth
import Develop.DatFw.Form
import Develop.DatFw.Form.Fields
import Text.Blaze

import Data.Text as T
import Control.Monad.IO.Class   -- imports liftIO
import Data.Time

-- ---------------------------------------------------------------

markdownField :: Field (HandlerFor ForumsApp) Markdown
markdownField = checkMap
        (\ t -> if T.length t < 20 then Left "Text massa curt" else Right (Markdown t))
        getMdText
        textareaField

---------------------------------------------------------------------

newForumForm :: AForm (HandlerFor ForumsApp) NewForum
newForumForm =
    NewForum <$> freq textField (withPlaceholder "Introduce forum's title" "Title") Nothing
             <*> freq markdownField (withPlaceholder "Introduce description" "Descrition") Nothing
             <*> (fst <$> freq (checkMMap checkUserExists (udName . snd) textField)
                   (withPlaceholder "Introduce moderator's name" "Moderator's name")
                   Nothing)

newTopicForm :: AForm (HandlerFor ForumsApp) NewTopic
newTopicForm = 
    NewTopic <$> freq textField (withPlaceholder "Introduce topic title" "Title") Nothing
             <*> freq markdownField (withPlaceholder "Introduce topic description" "Description") Nothing

newReplyForm :: AForm (HandlerFor ForumsApp) Markdown
newReplyForm = freq markdownField (withPlaceholder "Introduce reply" "Reply") Nothing

editForumForm :: AForm (HandlerFor ForumsApp) EditForum
editForumForm =
    EditForum <$> freq textField (withPlaceholder "Introduce new forum's title" "Title") Nothing 
             <*> freq markdownField (withPlaceholder "Introduce new description" "Description") Nothing

---------------------------------------------------------------------

checkUserExists :: Text -> HandlerFor ForumsApp (Either Text (UserId, UserD))
checkUserExists uname = do
    mbu <- runDbAction $ getUserByName uname
    pure $ maybe (Left "L'usuari no existeix") Right mbu

getHomeR :: HandlerFor ForumsApp Html
getHomeR = do
    -- Get authenticated user
    mbuser <- maybeAuth
    -- Get a fresh form
    fformw <- generateAFormPost newForumForm
    -- Return HTML content
    defaultLayout $ homeView mbuser fformw

postHomeR :: HandlerFor ForumsApp Html
postHomeR = do
    user <- requireAuth
    (fformr, fformw) <- runAFormPost newForumForm
    case fformr of
        FormSuccess newtheme -> do
            now <- liftIO getCurrentTime
            runDbAction $ addForum newtheme now
            redirect HomeR
        _ ->
            defaultLayout $ homeView (Just user) fformw


getForumR :: ForumId -> HandlerFor ForumsApp Html
getForumR fid = do
    -- Get requested forum from data-base.
    -- Short-circuit (responds immediately) with a 'Not found' status if forum don't exist
    forum <- runDbAction (getForum fid) >>= maybe notFound pure
    mbuser <- maybeAuth
    -- Other processing (forms, ...)
    tformw <- generateAFormPost newTopicForm
    eformw <- generateAFormPost editForumForm
    -- Return HTML content
    defaultLayout $ forumView mbuser (fid, forum) tformw eformw

postForumR :: ForumId -> HandlerFor ForumsApp Html
postForumR fid = do
    user <- requireAuth
    forum <- runDbAction (getForum fid) >>= maybe notFound pure
    eformw <- generateAFormPost editForumForm
    (tformr, tformw) <- runAFormPost newTopicForm
    case tformr of
        FormSuccess newtopic -> do
            now <- liftIO getCurrentTime
            runDbAction $ addTopic fid (fst user) newtopic now
            redirect (ForumR fid)
        _ ->
            defaultLayout $ forumView (Just user) (fid, forum) tformw eformw

postModifyForumR :: ForumId -> HandlerFor ForumsApp Html
postModifyForumR fid = do
    user <- requireAuth
    forum <- runDbAction (getForum fid) >>= maybe notFound pure
    tformw <- generateAFormPost newTopicForm
    (eformr, eformw) <- runAFormPost editForumForm
    case eformr of
        FormSuccess editedforum -> do
           runDbAction $ editForum fid (efTitle editedforum) (efDescription editedforum)
           redirect (ForumR fid)
        _ ->
           defaultLayout $ forumView (Just user) (fid, forum) tformw eformw

getTopicR :: TopicId -> HandlerFor ForumsApp Html
getTopicR tid = do
    -- Get resquested forum from data-base.
    topic <- runDbAction (getTopic tid) >>= maybe notFound pure
    mbuser <- maybeAuth
    -- Other processing (forms, ...)
    rformw <- generateAFormPost newReplyForm
    -- Return HTML content
    defaultLayout $ topicView mbuser (tid, topic) rformw

getDeleteTopicR :: TopicId -> HandlerFor ForumsApp Html
getDeleteTopicR tid = do
    user <- requireAuth
    topic <- runDbAction (getTopic tid) >>= maybe notFound pure
    runDbAction $ deleteTopic (tdForumId topic) tid
    redirect (ForumR (tdForumId topic))

getDeletePostR :: PostId -> HandlerFor ForumsApp Html
getDeletePostR pid = do
    user <- requireAuth
    post <- runDbAction (getPost pid) >>= maybe notFound pure
    topic <- runDbAction (getTopic (pdTopicId post)) >>= maybe notFound pure
    runDbAction $ deletePost (tdForumId topic) (pdTopicId post) pid
    redirect (TopicR (pdTopicId post))

postTopicR :: TopicId -> HandlerFor ForumsApp Html
postTopicR tid = do
    user <- requireAuth
    topic <- runDbAction (getTopic tid) >>= maybe notFound pure
    (rformr, rformw) <- runAFormPost newReplyForm
    case rformr of
        FormSuccess newreply -> do
            now <- liftIO getCurrentTime
            runDbAction $ addReply (tdForumId topic) tid (fst user) newreply now
            redirect (TopicR tid)
        _ ->
            defaultLayout $ topicView (Just user) (tid, topic) rformw




