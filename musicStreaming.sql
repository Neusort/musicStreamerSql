-- Users table to store user information
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Artists table
CREATE TABLE artists (
    artist_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    bio TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Albums table with foreign key to artists
CREATE TABLE albums (
    album_id SERIAL PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    artist_id INTEGER REFERENCES artists(artist_id),
    release_date DATE NOT NULL,
    cover_art_url VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Songs table with foreign key to albums
CREATE TABLE songs (
    song_id SERIAL PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    album_id INTEGER REFERENCES albums(album_id),
    duration INTEGER NOT NULL, -- Duration in seconds
    track_number INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Playlists table
CREATE TABLE playlists (
    playlist_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    user_id INTEGER REFERENCES users(user_id),
    is_public BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Playlist_songs junction table
CREATE TABLE playlist_songs (
    playlist_id INTEGER REFERENCES playlists(playlist_id),
    song_id INTEGER REFERENCES songs(song_id),
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (playlist_id, song_id)
);

-- User listening history
CREATE TABLE listening_history (
    history_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(user_id),
    song_id INTEGER REFERENCES songs(song_id),
    listened_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User follows (both users and artists)
CREATE TABLE follows (
    follower_id INTEGER REFERENCES users(user_id),
    followee_type VARCHAR(10) CHECK (followee_type IN ('user', 'artist')),
    followee_id INTEGER,
    followed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (follower_id, followee_type, followee_id)
);

-- User preferences
CREATE TABLE user_preferences (
    user_id INTEGER REFERENCES users(user_id),
    preference_type VARCHAR(20) CHECK (preference_type IN ('genre', 'artist')),
    preference_value INTEGER, -- Can be genre_id or artist_id
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, preference_type, preference_value)
);

-- Genres table
CREATE TABLE genres (
    genre_id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL
);

-- Song genres junction table
CREATE TABLE song_genres (
    song_id INTEGER REFERENCES songs(song_id),
    genre_id INTEGER REFERENCES genres(genre_id),
    PRIMARY KEY (song_id, genre_id)
);

-- Query 1: Top 10 most played songs in a given week
SELECT 
    s.song_id,
    s.title,
    a.name as artist_name,
    COUNT(*) as play_count
FROM listening_history lh
JOIN songs s ON lh.song_id = s.song_id
JOIN albums alb ON s.album_id = alb.album_id
JOIN artists a ON alb.artist_id = a.artist_id
WHERE lh.listened_at >= NOW() - INTERVAL '1 week'
GROUP BY s.song_id, s.title, a.name
ORDER BY play_count DESC
LIMIT 10;

-- Query 2: All albums by a particular artist, ordered by release date
SELECT 
    album_id,
    title,
    release_date,
    cover_art_url
FROM albums
WHERE artist_id = :artist_id
ORDER BY release_date DESC;

-- Query 3: Find users who have a specific song in their playlist
SELECT DISTINCT
    u.user_id,
    u.username
FROM users u
JOIN playlists p ON u.user_id = p.user_id
JOIN playlist_songs ps ON p.playlist_id = ps.playlist_id
WHERE ps.song_id = :song_id;

-- Query 4: Artists with the most followers
SELECT 
    a.artist_id,
    a.name,
    COUNT(*) as follower_count
FROM artists a
JOIN follows f ON a.artist_id = f.followee_id
WHERE f.followee_type = 'artist'
GROUP BY a.artist_id, a.name
ORDER BY follower_count DESC;

-- Query 5: User listening history for a specific date range
SELECT 
    s.title,
    a.name as artist_name,
    alb.title as album_name,
    lh.listened_at
FROM listening_history lh
JOIN songs s ON lh.song_id = s.song_id
JOIN albums alb ON s.album_id = alb.album_id
JOIN artists a ON alb.artist_id = a.artist_id
WHERE lh.user_id = :user_id
    AND lh.listened_at BETWEEN :start_date AND :end_date
ORDER BY lh.listened_at DESC;

-- Query 6: Song recommendations based on user history and preferences
WITH user_favorite_genres AS (
    SELECT 
        preference_value as genre_id
    FROM user_preferences
    WHERE user_id = :user_id 
        AND preference_type = 'genre'
),
user_listened_songs AS (
    SELECT DISTINCT song_id 
    FROM listening_history 
    WHERE user_id = :user_id
)
SELECT DISTINCT
    s.song_id,
    s.title,
    a.name as artist_name,
    alb.title as album_name
FROM songs s
JOIN albums alb ON s.album_id = alb.album_id
JOIN artists a ON alb.artist_id = a.artist_id
JOIN song_genres sg ON s.song_id = sg.song_id
JOIN user_favorite_genres ufg ON sg.genre_id = ufg.genre_id
WHERE s.song_id NOT IN (SELECT song_id FROM user_listened_songs)
ORDER BY 
    (
        SELECT COUNT(*) 
        FROM listening_history lh 
        WHERE lh.song_id = s.song_id
    ) DESC
LIMIT 10;

-- Indexes for better query performance
CREATE INDEX idx_listening_history_user_id ON listening_history(user_id);
CREATE INDEX idx_listening_history_song_id ON listening_history(song_id);
CREATE INDEX idx_listening_history_listened_at ON listening_history(listened_at);
CREATE INDEX idx_follows_followee ON follows(followee_type, followee_id);
CREATE INDEX idx_user_preferences_user ON user_preferences(user_id, preference_type);
CREATE INDEX idx_playlist_songs_song ON playlist_songs(song_id);