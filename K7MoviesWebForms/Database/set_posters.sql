USE MovieTicketBookingDB;
GO
-- links each movie to its poster file in the posters folder
UPDATE dbo.Movies SET PosterPath = N'/posters/aasai.jpg' WHERE Title = N'Aasai';
UPDATE dbo.Movies SET PosterPath = N'/posters/anbil.jpg' WHERE Title = N'Anbil Avan';
UPDATE dbo.Movies SET PosterPath = N'/posters/black.jpg' WHERE Title = N'Black Gold';
UPDATE dbo.Movies SET PosterPath = N'/posters/city.jpg' WHERE Title = N'Con City';
UPDATE dbo.Movies SET PosterPath = N'/posters/drones.jpg' WHERE Title = N'Drones';
UPDATE dbo.Movies SET PosterPath = N'/posters/ha.jpg' WHERE Title = N'Habeebi';
UPDATE dbo.Movies SET PosterPath = N'/posters/ida.jpg' WHERE Title = N'Idhayam Murali';
UPDATE dbo.Movies SET PosterPath = N'/posters/jailer2.jpg' WHERE Title = N'Jailer 2';
UPDATE dbo.Movies SET PosterPath = N'/posters/jana.jpg' WHERE Title = N'Jana Nayagan';
UPDATE dbo.Movies SET PosterPath = N'/posters/karrupu.jpg' WHERE Title = N'Karuppu';
UPDATE dbo.Movies SET PosterPath = N'/posters/kutty.jpg' WHERE Title = N'Appa Kutty';
UPDATE dbo.Movies SET PosterPath = N'/posters/lp.jpg' WHERE Title = N'Lakshmikanthan Kolai Vazhakku';
UPDATE dbo.Movies SET PosterPath = N'/posters/maru.jpg' WHERE Title = N'Maaruvesham';
UPDATE dbo.Movies SET PosterPath = N'/posters/mook.jpg' WHERE Title = N'Mookuthi Amman 2';
UPDATE dbo.Movies SET PosterPath = N'/posters/mud.jpg' WHERE Title = N'Mudharkanal';
UPDATE dbo.Movies SET PosterPath = N'/posters/ranabaali.jpg' WHERE Title = N'Ranabaali';
UPDATE dbo.Movies SET PosterPath = N'/posters/sardar.jpg' WHERE Title = N'Sardar 2';
UPDATE dbo.Movies SET PosterPath = N'/posters/scene.jpg' WHERE Title = N'Scene';
UPDATE dbo.Movies SET PosterPath = N'/posters/seyon.jpg' WHERE Title = N'Seyon';
UPDATE dbo.Movies SET PosterPath = N'/posters/sigma.jpg' WHERE Title = N'Sigma';
UPDATE dbo.Movies SET PosterPath = N'/posters/siva.jpg' WHERE Title = N'Picasso';
UPDATE dbo.Movies SET PosterPath = N'/posters/soori.jpg' WHERE Title = N'Mandaadi';
UPDATE dbo.Movies SET PosterPath = N'/posters/titanic.jpg' WHERE Title = N'Titanic';
UPDATE dbo.Movies SET PosterPath = N'/posters/trouble.jpg' WHERE Title = N'Don''t Trouble The Trouble';
UPDATE dbo.Movies SET PosterPath = N'/posters/vaa.jpg' WHERE Title = N'Vaa Deal';
UPDATE dbo.Movies SET PosterPath = N'/posters/varavu.jpg' WHERE Title = N'Varavu';
UPDATE dbo.Movies SET PosterPath = N'/posters/vasu.jpg' WHERE Title = N'Vasudheva Sutham';
UPDATE dbo.Movies SET PosterPath = N'/posters/yellow.jpg' WHERE Title = N'Yellow Yellow Dirty Fellow';
UPDATE dbo.Movies SET PosterPath = N'/posters/yezhu.jpg' WHERE Title = N'Yezhu Kadal Yezhu Malai';
GO
SELECT COUNT(*) AS MoviesWithPoster FROM dbo.Movies WHERE PosterPath IS NOT NULL AND PosterPath <> N'';
GO
