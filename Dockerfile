FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=3000

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

COPY . .

# Bothost may reuse Docker layers from an older build where the project had
# a local /app/agents package. It shadows the OpenAI Agents SDK package.
RUN rm -rf /app/agents \
    && python -c "from agents import Agent, Runner; print('OpenAI Agents SDK import OK')"

EXPOSE 3000

CMD ["python", "bot.py"]
