import psycopg2

try:
    conn = psycopg2.connect("postgresql://abmsalesdatabase:rTzYrF3GO4b0bzCNtsmdzuaAYnnfPmJN@dpg-d1g0cmali9vc73a392lg-a.oregon-postgres.render.com/abmsalesdatabase")
    print("Connexion réussie")
except Exception as e:
    print("Erreur de connexion :", e)   