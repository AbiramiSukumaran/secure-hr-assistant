import streamlit as st
import psycopg2
from google.cloud import aiplatform
import vertexai
from vertexai.language_models import TextEmbeddingModel

# CONFIG
DB_HOST = "************" # Your AlloyDB IP
DB_NAME = "postgres"
DB_USER = "postgres" 
DB_PASS = "alloydb"

# Initialize Vertex AI for Embeddings (if using RAG)
vertexai.init(project="your-project", location="us-central1")
embedding_model = TextEmbeddingModel.from_pretrained("text-embedding-004")

def get_db_connection():
    conn = psycopg2.connect(
        host=DB_HOST, database=DB_NAME, user=DB_USER, password=DB_PASS
    )
    return conn

def query_database(user_name, query_text):
    """
    Executes a query or RAG search acting AS the specific user.
    """
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            # 1. SECURITY STEP: Identify the User
            # We use 'app.active_user' to avoid conflict with reserved keyword 'current_user'
            cur.execute(f"SET app.active_user = '{user_name}';")
            
            # 2. Run the Query
            # The RLS policies will check 'user_roles' table automatically.
            sql = "SELECT name, salary, performance_review FROM employees;"
            cur.execute(sql)
            results = cur.fetchall()
            
            return results
    finally:
        conn.close()

# --- STREAMLIT UI ---
st.title("🛡️ The Private Vault: RLS Demo")

# 1. Identity Switcher (Simulating Login)
user_selection = st.sidebar.radio(
    "Act as User:",
    ("Alice", "Bob", "Charlie")
)

st.write(f"Logged in as: **{user_selection}**")

# 2. Chat Interface
user_query = st.text_input("Ask about employee data:", "Show me all salaries")

if st.button("Ask Database"):
    data = query_database(user_selection, user_query)
    
    if not data:
        st.error("🚫 Access Denied or No Data Found.")
    else:
        st.success(f"Found {len(data)} records authorized for {user_selection}.")
        for row in data:
            st.write(f"👤 **Name:** {row[0]} | 💰 **Salary:** ${row[1]} | 📝 **Review:** {row[2]}")

st.markdown("---")
st.caption("Notice: Alice only sees Alice. Bob (Manager) sees everyone.")
